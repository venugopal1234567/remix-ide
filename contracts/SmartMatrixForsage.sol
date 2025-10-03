// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SmartMatrixForsage
 * @dev A matrix-based referral system implementing X3 matrix structure
 * Users can register, upgrade levels, and earn through a multi-level matrix system
 */
contract SmartMatrixForsage {
    
    struct User {
        uint256 id;
        address referrer;
        uint256 partnersCount;
        uint256 totalEarned;
        uint256 availableBalance;
        
        mapping(uint8 => bool) activeX3Levels;
        mapping(uint8 => X3) x3Matrix;
    }
    
    struct X3 {
        address currentReferrer;
        address[] referrals;
        bool blocked;
        uint256 reinvestCount;
    }

    uint8 public constant LAST_LEVEL = 12;
    
    mapping(address => User) public users;
    mapping(uint256 => address) public idToAddress;
    mapping(uint256 => address) public userIds;

    uint256 public lastUserId = 2;
    address public immutable owner;
    
    mapping(uint8 => uint256) public levelPrice;
    
    event Registration(address indexed user, address indexed referrer, uint256 indexed userId, uint256 referrerId);
    event Reinvest(address indexed user, address indexed currentReferrer, address indexed caller, uint8 matrix, uint8 level);
    event Upgrade(address indexed user, address indexed referrer, uint8 matrix, uint8 level);
    event NewUserPlace(address indexed user, address indexed referrer, uint8 matrix, uint8 level, uint8 place);
    event MissedEthReceive(address indexed receiver, address indexed from, uint8 matrix, uint8 level);
    event SentExtraEthDividends(address indexed from, address indexed receiver, uint8 matrix, uint8 level);
    
    event EarningsCredited(address indexed user, address indexed from, uint8 matrix, uint8 level, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    
    
    /**
     * @dev Constructor initializes the contract with owner and level prices
     * @param ownerAddress Address of the contract owner (first user with ID 1)
     * Level prices start at 0.025 ETH and double at each level
     */
    constructor(address ownerAddress) {
        require(ownerAddress != address(0), "Invalid owner address");
        
        levelPrice[1] = 0.025 ether;
        for (uint8 i = 2; i <= LAST_LEVEL; i++) {
            levelPrice[i] = levelPrice[i-1] * 2;
        }
        
        owner = ownerAddress;
        
        User storage user = users[ownerAddress];
        user.id = 1;
        user.referrer = address(0);
        user.partnersCount = 0;
        user.totalEarned = 0;
        user.availableBalance = 0;
        
        idToAddress[1] = ownerAddress;
        
        for (uint8 i = 1; i <= LAST_LEVEL; i++) {
            users[ownerAddress].activeX3Levels[i] = true;
        }
        
        userIds[1] = ownerAddress;
    }
    
    /**
     * @dev Fallback function to handle direct ETH transfers
     * Automatically registers sender with owner as referrer
     */
    receive() external payable {
        registration(msg.sender, owner);
    }
    
    /**
     * @dev Fallback function to handle calls with data
     * If data is 20 bytes (address), uses it as referrer; otherwise uses owner
     */
    fallback() external payable {
        if(msg.data.length == 20) {
            registration(msg.sender, bytesToAddress(msg.data));
        } else {
            registration(msg.sender, owner);
        }
    }

    /**
     * @dev External function for user registration with specific referrer
     * @param referrerAddress Address of the referrer
     * Requires exactly 0.05 ETH payment
     */
    function registrationExt(address referrerAddress) external payable {
        registration(msg.sender, referrerAddress);
    }
    
    /**
     * @dev Allows existing users to purchase and activate a new level
     * @param matrix Matrix type (must be 1 for X3)
     * @param level Level to activate (2-12)
     * Requires payment equal to the level price
     */
    function buyNewLevel(uint8 matrix, uint8 level) external payable {
        require(isUserExists(msg.sender), "user is not exists. Register first.");
        require(matrix == 1, "invalid matrix");
        require(msg.value == levelPrice[level], "invalid price");
        require(level > 1 && level <= LAST_LEVEL, "invalid level");

        require(!users[msg.sender].activeX3Levels[level], "level already activated");

        if (users[msg.sender].x3Matrix[level-1].blocked) {
            users[msg.sender].x3Matrix[level-1].blocked = false;
        }

        address freeX3Referrer = findFreeX3Referrer(msg.sender, level);
        users[msg.sender].x3Matrix[level].currentReferrer = freeX3Referrer;
        users[msg.sender].activeX3Levels[level] = true;
        updateX3Referrer(msg.sender, freeX3Referrer, level);
        
        emit Upgrade(msg.sender, freeX3Referrer, 1, level);
    }    
    
    /**
     * @dev Internal function to register a new user
     * @param userAddress Address of the new user
     * @param referrerAddress Address of the referrer
     * Requires exactly 0.05 ETH and prevents contract addresses from registering
     */
    function registration(address userAddress, address referrerAddress) private {
        require(msg.value == 0.05 ether, "registration cost 0.05");
        require(!isUserExists(userAddress), "user exists");
        require(isUserExists(referrerAddress), "referrer not exists");
        
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "cannot be a contract");
        
        User storage user = users[userAddress];
        user.id = lastUserId;
        user.referrer = referrerAddress;
        user.partnersCount = 0;
        user.totalEarned = 0;
        user.availableBalance = 0;
        
        idToAddress[lastUserId] = userAddress;
        users[userAddress].activeX3Levels[1] = true; 
        
        userIds[lastUserId] = userAddress;
        lastUserId++;
        
        users[referrerAddress].partnersCount++;

        address freeX3Referrer = findFreeX3Referrer(userAddress, 1);
        users[userAddress].x3Matrix[1].currentReferrer = freeX3Referrer;
        updateX3Referrer(userAddress, freeX3Referrer, 1);
        
        emit Registration(userAddress, referrerAddress, users[userAddress].id, users[referrerAddress].id);
    }
    
    /**
     * @dev Updates the X3 matrix by adding a user to a referrer's matrix
     * @param userAddress Address of the user being added
     * @param referrerAddress Address of the referrer
     * @param level Matrix level being updated
     * Handles matrix cycling and reinvestment when 3 referrals are reached
     */
    function updateX3Referrer(address userAddress, address referrerAddress, uint8 level) private {
        users[referrerAddress].x3Matrix[level].referrals.push(userAddress);

        if (users[referrerAddress].x3Matrix[level].referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(users[referrerAddress].x3Matrix[level].referrals.length));
            return sendETHDividends(referrerAddress, userAddress, 1, level);
        }
        
        emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
        delete users[referrerAddress].x3Matrix[level].referrals;
        if (!users[referrerAddress].activeX3Levels[level+1] && level != LAST_LEVEL) {
            users[referrerAddress].x3Matrix[level].blocked = true;
        }

        if (referrerAddress != owner) {
            address freeReferrerAddress = findFreeX3Referrer(referrerAddress, level);
            if (users[referrerAddress].x3Matrix[level].currentReferrer != freeReferrerAddress) {
                users[referrerAddress].x3Matrix[level].currentReferrer = freeReferrerAddress;
            }
            
            users[referrerAddress].x3Matrix[level].reinvestCount++;
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updateX3Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendETHDividends(owner, userAddress, 1, level);
            users[owner].x3Matrix[level].reinvestCount++;
            emit Reinvest(owner, address(0), userAddress, 1, level);
        }
    }
    
    /**
     * @dev Finds the first active referrer up the referral chain for a given level
     * @param userAddress Starting user address
     * @param level Level to check for active referrer
     * @return Address of the first active referrer in the chain
     */
    function findFreeX3Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX3Levels[level]) {
                return users[userAddress].referrer;
            }
            
            userAddress = users[userAddress].referrer;
        }
    }
    
    /**
     * @dev Checks if a user has activated a specific X3 level
     * @param userAddress Address to check
     * @param level Level to check
     * @return Boolean indicating if level is active
     */
    function usersActiveX3Levels(address userAddress, uint8 level) public view returns(bool) {
        return users[userAddress].activeX3Levels[level];
    }

    /**
     * @dev Returns X3 matrix information for a user at a specific level
     * @param userAddress Address to query
     * @param level Level to query
     * @return Current referrer, array of referrals, and blocked status
     */
    function usersX3Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, bool) {
        return (users[userAddress].x3Matrix[level].currentReferrer,
                users[userAddress].x3Matrix[level].referrals,
                users[userAddress].x3Matrix[level].blocked);
    }
    
    /**
     * @dev Checks if a user exists in the system
     * @param user Address to check
     * @return Boolean indicating if user is registered
     */
    function isUserExists(address user) public view returns (bool) {
        return (users[user].id != 0);
    }

    /**
     * @dev Finds the actual ETH receiver, skipping blocked matrices
     * @param userAddress Initial receiver address
     * @param _from Address of the sender
     * @param matrix Matrix type
     * @param level Matrix level
     * @return receiver Final receiver address and whether extra dividends were sent
     */
    function findEthReceiver(address userAddress, address _from, uint8 matrix, uint8 level) private returns(address, bool) {
        address receiver = userAddress;
        bool isExtraDividends;
        
        while (true) {
            if (users[receiver].x3Matrix[level].blocked) {
                emit MissedEthReceive(receiver, _from, 1, level);
                isExtraDividends = true;
                receiver = users[receiver].x3Matrix[level].currentReferrer;
            } else {
                return (receiver, isExtraDividends);
            }
        }
    }

    /**
     * @dev Credits ETH dividends to user's available balance
     * @param userAddress Address to receive dividends
     * @param _from Address of the payer
     * @param matrix Matrix type
     * @param level Matrix level
     * Automatically finds unblocked receiver and credits their balance
     */
    function sendETHDividends(address userAddress, address _from, uint8 matrix, uint8 level) private {
        (address receiver, bool isExtraDividends) = findEthReceiver(userAddress, _from, matrix, level);

        uint256 amount = levelPrice[level];
        
        users[receiver].totalEarned += amount;
        users[receiver].availableBalance += amount;
        
        emit EarningsCredited(receiver, _from, matrix, level, amount);
        
        if (isExtraDividends) {
            emit SentExtraEthDividends(_from, receiver, matrix, level);
        }
    }
    
    /**
     * @dev Withdraws entire available balance to the caller
     * Requires user to be registered and have positive balance
     */
    function withdraw() external {
        require(isUserExists(msg.sender), "User not registered");
        uint256 amount = users[msg.sender].availableBalance;
        require(amount > 0, "No balance to withdraw");
        
        users[msg.sender].availableBalance = 0;
        
        emit Withdrawal(msg.sender, amount);
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Withdraws a specific amount from available balance
     * @param _amount Amount to withdraw in wei
     * Requires sufficient balance and positive amount
     */
    function withdrawAmount(uint256 _amount) external {
        require(isUserExists(msg.sender), "User not registered");
        require(_amount > 0, "Amount must be positive");
        require(users[msg.sender].availableBalance >= _amount, "Insufficient balance");
        
        users[msg.sender].availableBalance -= _amount;
        
        emit Withdrawal(msg.sender, _amount);
        
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Returns the balance information for a user
     * @param _user Address to query
     * @return totalEarned Total cumulative earnings
     * @return availableBalance Current withdrawable balance
     */
    function getUserBalance(address _user) external view returns (uint256 totalEarned, uint256 availableBalance) {
        require(isUserExists(_user), "User does not exist");
        return (users[_user].totalEarned, users[_user].availableBalance);
    }
    
    /**
     * @dev Returns the total ETH balance held by the contract
     * @return Contract balance in wei
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Converts bytes to address (used in fallback function)
     * @param bys Bytes to convert
     * @return addr Extracted address
     */
    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
}