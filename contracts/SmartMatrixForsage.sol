// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    
    receive() external payable {
        registration(msg.sender, owner);
    }
    
    fallback() external payable {
        if(msg.data.length == 20) {
            registration(msg.sender, bytesToAddress(msg.data));
        } else {
            registration(msg.sender, owner);
        }
    }

    function registrationExt(address referrerAddress) external payable {
        registration(msg.sender, referrerAddress);
    }
    
    function buyNewLevel(uint8 matrix, uint8 level) external payable {
        require(isUserExists(msg.sender), "user is not exists. Register first.");
        require(matrix == 1, "invalid matrix"); // Only X3 (matrix 1) allowed now
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
    
    function updateX3Referrer(address userAddress, address referrerAddress, uint8 level) private {
        users[referrerAddress].x3Matrix[level].referrals.push(userAddress);

        if (users[referrerAddress].x3Matrix[level].referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(users[referrerAddress].x3Matrix[level].referrals.length));
            return sendETHDividends(referrerAddress, userAddress, 1, level);
        }
        
        emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
        //close matrix
        delete users[referrerAddress].x3Matrix[level].referrals;
        if (!users[referrerAddress].activeX3Levels[level+1] && level != LAST_LEVEL) {
            users[referrerAddress].x3Matrix[level].blocked = true;
        }

        //create new one by recursion
        if (referrerAddress != owner) {
            //check referrer active level
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
    
    function findFreeX3Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX3Levels[level]) {
                return users[userAddress].referrer;
            }
            
            userAddress = users[userAddress].referrer;
        }
    }
        
    function usersActiveX3Levels(address userAddress, uint8 level) public view returns(bool) {
        return users[userAddress].activeX3Levels[level];
    }

    function usersX3Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, bool) {
        return (users[userAddress].x3Matrix[level].currentReferrer,
                users[userAddress].x3Matrix[level].referrals,
                users[userAddress].x3Matrix[level].blocked);
    }
    
    function isUserExists(address user) public view returns (bool) {
        return (users[user].id != 0);
    }

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

    function sendETHDividends(address userAddress, address _from, uint8 matrix, uint8 level) private {
        (address receiver, bool isExtraDividends) = findEthReceiver(userAddress, _from, matrix, level);

        uint256 amount = levelPrice[level];
        
        // Credit to user's balance instead of sending directly
        users[receiver].totalEarned += amount;
        users[receiver].availableBalance += amount;
        
        emit EarningsCredited(receiver, _from, matrix, level, amount);
        
        if (isExtraDividends) {
            emit SentExtraEthDividends(_from, receiver, matrix, level);
        }
    }
    
    function withdraw() external {
        require(isUserExists(msg.sender), "User not registered");
        uint256 amount = users[msg.sender].availableBalance;
        require(amount > 0, "No balance to withdraw");
        
        users[msg.sender].availableBalance = 0;
        
        emit Withdrawal(msg.sender, amount);
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }
    
    function withdrawAmount(uint256 _amount) external {
        require(isUserExists(msg.sender), "User not registered");
        require(_amount > 0, "Amount must be positive");
        require(users[msg.sender].availableBalance >= _amount, "Insufficient balance");
        
        users[msg.sender].availableBalance -= _amount;
        
        emit Withdrawal(msg.sender, _amount);
        
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Withdrawal failed");
    }
    
    function getUserBalance(address _user) external view returns (uint256 totalEarned, uint256 availableBalance) {
        require(isUserExists(_user), "User does not exist");
        return (users[_user].totalEarned, users[_user].availableBalance);
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
}