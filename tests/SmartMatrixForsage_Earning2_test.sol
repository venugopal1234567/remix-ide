// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/SmartMatrixForsage.sol";

/**
 * Test Suite 2: Earnings & Balance
 * Tests earning mechanics and balance tracking
 * Note: Cannot test actual registration in beforeEach due to contract check
 */
contract EarningsTest {
    SmartMatrixForsage forsage;
    address acc0;
    address acc1;
    address acc2;
    
    function beforeAll() public {
        acc0 = TestsAccounts.getAccount(0);
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);
    }
    
    function beforeEach() public {
        forsage = new SmartMatrixForsage(acc0);
    }
    
    /// Test: Owner starts with zero earnings
    function testOwnerStartsZeroEarnings() public {
        (,,, uint256 totalEarned,) = forsage.users(acc0);
        Assert.equal(totalEarned, 0, "Owner should start with 0 earned");
    }
    
    /// Test: Owner starts with zero balance
    function testOwnerStartsZeroBalance() public {
        (,,,, uint256 availableBalance) = forsage.users(acc0);
        Assert.equal(availableBalance, 0, "Owner should start with 0 balance");
    }
    
    /// Test: getUserBalance works for owner
    function testGetUserBalanceOwner() public {
        (uint256 totalEarned, uint256 availableBalance) = forsage.getUserBalance(acc0);
        Assert.equal(totalEarned, 0, "Owner total earned should be 0");
        Assert.equal(availableBalance, 0, "Owner balance should be 0");
    }
    
    /// Test: Cannot query balance of non-existent user
    function testCannotQueryNonExistentUser() public {
        address fake = address(0x999);
        try forsage.getUserBalance(fake) {
            Assert.ok(false, "Should reject non-existent user");
        } catch {
            Assert.ok(true, "Correctly rejected non-existent user");
        }
    }
    
    /// Test: Contract balance starts at zero
    function testContractBalanceZero() public {
        uint256 balance = forsage.getContractBalance();
        Assert.equal(balance, 0, "Contract should start with 0 balance");
    }
    
    /// Test: User struct has correct fields
    function testUserStructFields() public {
        (uint256 id, address referrer, uint256 partnersCount, uint256 totalEarned, uint256 availableBalance) = forsage.users(acc0);
        Assert.equal(id, 1, "Owner ID");
        Assert.equal(referrer, address(0), "Owner referrer");
        Assert.equal(partnersCount, 0, "Owner partners");
        Assert.equal(totalEarned, 0, "Owner earned");
        Assert.equal(availableBalance, 0, "Owner balance");
    }
    
    /// Test: Balance query returns tuple correctly
    function testBalanceQueryReturnsTuple() public {
        (uint256 earned, uint256 balance) = forsage.getUserBalance(acc0);
        Assert.equal(earned, 0, "Earned should be 0");
        Assert.equal(balance, 0, "Balance should be 0");
    }
}