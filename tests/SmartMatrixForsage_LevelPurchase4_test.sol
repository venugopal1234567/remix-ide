// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/SmartMatrixForsage.sol";

/**
 * Test Suite 4: Level Purchase
 * Tests level activation and purchase mechanics without requiring registration
 */
contract LevelPurchaseTest {
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
    
    /// Test: Owner has Level 1 active
    function testOwnerLevel1Active() public {
        Assert.equal(forsage.usersActiveX3Levels(acc0, 1), true, "Owner level 1 should be active");
    }
    
    /// Test: Owner has all levels active
    function testOwnerAllLevelsActive() public {
        for (uint8 i = 1; i <= 12; i++) {
            Assert.equal(forsage.usersActiveX3Levels(acc0, i), true, "Owner should have all levels");
        }
    }
    
    /// Test: Non-registered user has no levels active
    function testNonUserNoLevels() public {
        Assert.equal(forsage.usersActiveX3Levels(acc1, 1), false, "Non-user should have no levels");
        Assert.equal(forsage.usersActiveX3Levels(acc1, 2), false, "Non-user should have no levels");
    }
    
    /// Test: Cannot buy level without being registered
    function testRejectBuyLevelUnregistered() public {
        try forsage.buyNewLevel{value: 0.05 ether}(1, 2) {
            Assert.ok(false, "Should reject unregistered user");
        } catch {
            Assert.ok(true, "Correctly rejected unregistered user");
        }
    }
    
    /// Test: Reject invalid matrix number
    function testRejectInvalidMatrix() public {
        try forsage.buyNewLevel{value: 0.05 ether}(2, 2) {
            Assert.ok(false, "Should reject matrix 2");
        } catch {
            Assert.ok(true, "Correctly rejected invalid matrix");
        }
    }
    
    /// Test: Reject invalid level (0)
    function testRejectLevelZero() public {
        try forsage.buyNewLevel{value: 0.025 ether}(1, 0) {
            Assert.ok(false, "Should reject level 0");
        } catch {
            Assert.ok(true, "Correctly rejected level 0");
        }
    }
    
    /// Test: Reject invalid level (above 12)
    function testRejectLevelAbove12() public {
        try forsage.buyNewLevel{value: 1 ether}(1, 13) {
            Assert.ok(false, "Should reject level 13");
        } catch {
            Assert.ok(true, "Correctly rejected level above 12");
        }
    }
    
    /// Test: Level prices double correctly
    function testLevelPricesDouble() public {
        Assert.equal(forsage.levelPrice(1), 0.025 ether, "Level 1");
        Assert.equal(forsage.levelPrice(2), 0.05 ether, "Level 2");
        Assert.equal(forsage.levelPrice(3), 0.1 ether, "Level 3");
        Assert.equal(forsage.levelPrice(4), 0.2 ether, "Level 4");
        Assert.equal(forsage.levelPrice(12), 51.2 ether, "Level 12");
    }
    
    /// Test: View function usersActiveX3Levels works
    function testViewFunctionWorks() public {
        bool isActive = forsage.usersActiveX3Levels(acc0, 1);
        Assert.equal(isActive, true, "View function should work");
    }
    
    /// Test: LAST_LEVEL constant is correct
    function testLastLevelConstant() public {
        Assert.equal(forsage.LAST_LEVEL(), 12, "LAST_LEVEL should be 12");
    }
}