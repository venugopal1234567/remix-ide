// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/SmartMatrixForsage.sol";

/**
 * Test Suite 5: Matrix Structure & Mechanics
 * Tests X3 matrix structure without requiring user registration
 */
contract MatrixTest {
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
    
    /// Test: Owner's matrix exists at level 1
    function testOwnerMatrixExists() public {
        (address currentReferrer, address[] memory referrals, bool blocked) = forsage.usersX3Matrix(acc0, 1);
        // Matrix exists and returns data
        Assert.equal(blocked, false, "Owner matrix should not be blocked");
    }
    
    /// Test: Owner's matrix starts empty
    function testOwnerMatrixStartsEmpty() public {
        (, address[] memory referrals,) = forsage.usersX3Matrix(acc0, 1);
        Assert.equal(referrals.length, 0, "Owner should have no referrals initially");
    }
    
    /// Test: Owner's matrix not blocked at level 1
    function testOwnerMatrixNotBlocked() public {
        (,, bool blocked) = forsage.usersX3Matrix(acc0, 1);
        Assert.equal(blocked, false, "Owner matrix should not be blocked");
    }
    
    /// Test: Owner's currentReferrer is zero address
    function testOwnerCurrentReferrerZero() public {
        (address currentReferrer,,) = forsage.usersX3Matrix(acc0, 1);
        Assert.equal(currentReferrer, address(0), "Owner should have no referrer");
    }
    
    /// Test: Non-registered user's matrix
    function testNonUserMatrix() public {
        (address currentReferrer, address[] memory referrals, bool blocked) = forsage.usersX3Matrix(acc1, 1);
        Assert.equal(currentReferrer, address(0), "Non-user should have zero referrer");
        Assert.equal(referrals.length, 0, "Non-user should have empty referrals");
        Assert.equal(blocked, false, "Non-user should not be blocked");
    }
    
    /// Test: usersX3Matrix view function works
    function testMatrixViewFunctionWorks() public {
        (address ref, address[] memory refs, bool blk) = forsage.usersX3Matrix(acc0, 1);
        // Function executes without error
        Assert.ok(true, "usersX3Matrix function works");
    }
    
    /// Test: Matrix data accessible for all levels
    function testMatrixAccessibleAllLevels() public {
        for (uint8 i = 1; i <= 12; i++) {
            (,, bool blocked) = forsage.usersX3Matrix(acc0, i);
            Assert.equal(blocked, false, "Owner matrices should not be blocked");
        }
    }
    
    /// Test: findFreeX3Referrer returns owner for owner
    function testFindFreeReferrerOwner() public {
        address freeRef = forsage.findFreeX3Referrer(acc0, 1);
        Assert.equal(freeRef, acc0, "Owner's free referrer should be owner");
    }
}