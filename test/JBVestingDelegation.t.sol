// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/JBVestingDelegation.sol";

contract JBVestingDelegationTest is Test {
    uint256 amountToVest = 100 ether;

    address beneficiary = address(100);
    address authorizedSender = address(200);
    address unauthorizedSender = address(300);

    IERC20 jbxToken = IERC20(0x3abF2A4f8452cCC2CF7b4C1e4663147600646f66);
    IDelegateRegistry delegateRegistry =
        IDelegateRegistry(0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446);

    JBVestingDelegation vestingContract;

    function setUp() public {
        // -- test scene setting --
        deal(address(jbxToken), authorizedSender, amountToVest);
        deal(address(jbxToken), unauthorizedSender, amountToVest);

        vm.label(beneficiary, "beneficiary");
        vm.label(authorizedSender, "authorizedSender");
        vm.label(unauthorizedSender, "unauthorizedSender");
        vm.label(address(jbxToken), "jbxToken");
        vm.label(address(delegateRegistry), "delegateRegistry");

        // -- deploy --
        vestingContract = new JBVestingDelegation(
            jbxToken,
            delegateRegistry,
            beneficiary,
            authorizedSender
        );

        vm.warp(block.timestamp + 10);
    }

    function testAddToVesting_newVestingIfCorrectBeneficiary() public {
        uint256 delay = 100;
        vm.startPrank(authorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vestingContract.addToVesting(
            amountToVest,
            block.timestamp + delay,
            beneficiary
        );

        // 0 token are immediatably claimable
        assertEq(vestingContract.currentlyClaimable(), 0);

        // Half of the token are claimable after half the duration of vesting
        vm.warp(block.timestamp + (delay / 2));
        assertEq(vestingContract.currentlyClaimable(), amountToVest / 2);

        // All the token are claimable after the length of vesting
        vm.warp(block.timestamp + (delay / 2));
        assertEq(vestingContract.currentlyClaimable(), amountToVest);
    }

    function testAddToVesting_extendVestingIfCorrectBeneficiary() public {
        assertTrue(true);
    }

    function testAddToVesting_revertIfWrongBeneficiary() public {
        assertTrue(true);
    }

    function testAddToVesting_revertIfWrongSender() public {
        assertTrue(true);
    }
}
