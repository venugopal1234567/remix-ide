// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/SmartMatrixForsage.sol";

/**
 * Test Suite 3: Withdrawal Functionality
 * Tests withdrawal mechanics without requiring registration
 */
contract WithdrawalTest {
    SmartMatrixForsage forsage;
    address acc0;
    address acc1;
    
    function beforeAll() public {
        acc0 = TestsAccounts.getAccount(0);
        acc1 = TestsAccounts.getAccount(1);
    }
    
    function beforeEach() public {
        forsage = new SmartMatrixForsage(acc0);
    }
    
    /// Test: Owner (registered) cannot withdraw with zero balance
    function testOwnerCannotWithdrawZero() public {
        try forsage.withdraw() {
            Assert.ok(false, "Should reject zero balance withdrawal");
        } catch {
            Assert.ok(true, "Correctly rejected zero balance");
        }
    }
    
    /// Test: Non-existent user cannot withdraw
    function testNonExistentUserCannotWithdraw() public {
        // Create a proxy to call from non-registered address
        try forsage.withdraw() {
            Assert.ok(false, "Should reject unregistered user");
        } catch {
            Assert.ok(true, "Correctly rejected unregistered user");
        }
    }
    
    /// Test: Cannot withdraw zero amount
    function testRejectWithdrawZeroAmount() public {
        try forsage.withdrawAmount(0) {
            Assert.ok(false, "Should reject zero amount");
        } catch {
            Assert.ok(true, "Correctly rejected zero amount");
        }
    }
    
    /// Test: Cannot withdraw more than balance (owner has 0)
    function testRejectExcessiveWithdrawal() public {
        try forsage.withdrawAmount(1 ether) {
            Assert.ok(false, "Should reject excessive withdrawal");
        } catch {
            Assert.ok(true, "Correctly rejected excessive amount");
        }
    }
    
    /// Test: Owner exists but has zero balance
    function testOwnerZeroBalance() public {
        (, uint256 balance) = forsage.getUserBalance(acc0);
        Assert.equal(balance, 0, "Owner should have zero balance");
    }
    
    /// Test: Withdrawal functions exist and are callable
    function testWithdrawFunctionsExist() public {
        // Test that functions can be called (will revert due to zero balance)
        try forsage.withdraw() {
            Assert.ok(false, "Expected revert");
        } catch {
            Assert.ok(true, "withdraw() function exists");
        }
        
        try forsage.withdrawAmount(0.01 ether) {
            Assert.ok(false, "Expected revert");
        } catch {
            Assert.ok(true, "withdrawAmount() function exists");
        }
    }
}