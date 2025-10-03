// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/SmartMatrixForsage.sol";

/**
 * Test Suite 1: Registration Scenarios
 * Tests user registration functionality
 */
contract RegistrationTest {
    SmartMatrixForsage forsage;
    address acc0;
    address acc1;
    address acc2;
    
    // Use EOA addresses instead of test contract
    function beforeAll() public {
        acc0 = TestsAccounts.getAccount(0);
        acc1 = TestsAccounts.getAccount(1); 
        acc2 = TestsAccounts.getAccount(2);
    }
    
    function beforeEach() public {
        forsage = new SmartMatrixForsage(acc0);
    }
    
    /// Test: Owner is pre-registered
    function testOwnerIsRegistered() public {
        Assert.equal(forsage.isUserExists(acc0), true, "Owner should be registered");
    }
    
    /// Test: Owner has correct ID
    function testOwnerHasIDOne() public {
        (uint256 id,,,,) = forsage.users(acc0);
        Assert.equal(id, 1, "Owner ID should be 1");
    }
    
    /// Test: Owner has all levels active
    function testOwnerAllLevelsActive() public {
        Assert.equal(forsage.usersActiveX3Levels(acc0, 1), true, "Owner level 1 active");
        Assert.equal(forsage.usersActiveX3Levels(acc0, 2), true, "Owner level 2 active");
        Assert.equal(forsage.usersActiveX3Levels(acc0, 12), true, "Owner level 12 active");
    }
    
    /// Test: Level prices are correct
    function testLevelPrices() public {
        Assert.equal(forsage.levelPrice(1), 0.025 ether, "Level 1 price");
        Assert.equal(forsage.levelPrice(2), 0.05 ether, "Level 2 price");
        Assert.equal(forsage.levelPrice(3), 0.1 ether, "Level 3 price");
    }
    
    /// Test: Cannot register with wrong amount
    function testRejectWrongAmount() public {
        try forsage.registrationExt{value: 0.03 ether}(acc0) {
            Assert.ok(false, "Should reject wrong amount");
        } catch {
            // Correctly rejected (any error is acceptable)
            Assert.ok(true, "Correctly rejected wrong amount");
        }
    }
    
    /// Test: Cannot register non-existent referrer
    function testRejectNonExistentReferrer() public {
        address fakeReferrer = address(0x999);
        try forsage.registrationExt{value: 0.05 ether}(fakeReferrer) {
            Assert.ok(false, "Should reject non-existent referrer");
        } catch {
            // Correctly rejected (any error is acceptable)
            Assert.ok(true, "Correctly rejected non-existent referrer");
        }
    }
    
    /// Test: lastUserId starts at 2
    function testLastUserIdStartsAtTwo() public {
        Assert.equal(forsage.lastUserId(), 2, "lastUserId should start at 2");
    }
    
    /// Test: LAST_LEVEL constant is 12
    function testLastLevelConstant() public {
        Assert.equal(forsage.LAST_LEVEL(), 12, "LAST_LEVEL should be 12");
    }
    
    /// Test: Contract balance starts at zero
    function testContractBalanceZero() public {
        Assert.equal(forsage.getContractBalance(), 0, "Contract balance should be 0");
    }
    
    /// Test: Owner has zero partners initially
    function testOwnerZeroPartnersInitially() public {
        (,, uint256 partnersCount,,) = forsage.users(acc0);
        Assert.equal(partnersCount, 0, "Owner should have 0 partners initially");
    }
}