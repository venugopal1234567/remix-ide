
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import './FFATtoken.sol'; // Import the FFATtoken contract

contract BridgeBase {
    address public admin;
    FFATtoken public token; // Use FFATtoken directly
    uint public nonce;
    mapping(uint => bool) public processedNonces;

    enum Step { Burn, Mint }
    event Transfer(
        address from,
        address to,
        uint amount,
        uint date,
        uint nonce,
        Step indexed step
    );

    constructor(address _token) {
        admin = msg.sender;
        token = FFATtoken(_token); // Initialize the FFATtoken contract
    }

    function burn(address to, uint amount) external {
        // Transfer tokens from the sender to this contract
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Burn the tokens held by this contract
        token.burn(amount); // Burn the tokens on Polygon
        
        // Emit the Transfer event
        emit Transfer(
            msg.sender,
            to,
            amount,
            block.timestamp,
            nonce,
            Step.Burn
        );
        nonce++;
    }

    function mint(address to, uint amount, uint otherChainNonce) external {
        // Ensure only the admin can call this function
        require(msg.sender == admin, 'only admin');
        
        // Ensure the nonce has not been processed
        require(!processedNonces[otherChainNonce], 'transfer already processed');
        
        // Mark the nonce as processed
        processedNonces[otherChainNonce] = true;
        
        // Transfer tokens from the admin to the recipient
        require(token.transferFrom(admin, to, amount), "Transfer failed"); // Use transferFrom instead of transfer
        
        // Emit the Transfer event
        emit Transfer(
            msg.sender,
            to,
            amount,
            block.timestamp,
            otherChainNonce,
            Step.Mint
        );
    }
}