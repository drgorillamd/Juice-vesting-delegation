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

    function testAddToVesting_newVestingIfCorrectBeneficiary(uint128 delay)
        public
    {
        vm.assume(delay % 2 == 0 && delay > 0); // Avoid rounding errors
        vm.startPrank(authorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vestingContract.addToVesting(
            amountToVest,
            block.timestamp + delay,
            beneficiary
        );
        vm.stopPrank();

        uint256 startTimestamp = block.timestamp;

        // 0 token are immediatably claimable
        assertEq(vestingContract.currentlyClaimable(), 0);

        // Half of the token are claimable after half the duration of vesting
        vm.warp(startTimestamp + delay / 2);
        assertEq(vestingContract.currentlyClaimable(), amountToVest / 2);

        // All the token are claimable after the length of vesting
        vm.warp(startTimestamp + delay);
        assertEq(vestingContract.currentlyClaimable(), amountToVest);
    }

    function testAddToVesting_extendVestingIfCorrectBeneficiary() public {
        uint256 delay = 10000;
        uint256 secondVesting = 600;

        vm.startPrank(authorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vestingContract.addToVesting(
            amountToVest / 2,
            block.timestamp + delay,
            beneficiary
        );

        uint256 startTimestamp = block.timestamp;

        vm.warp(block.timestamp + secondVesting);

        vestingContract.addToVesting(
            amountToVest / 2,
            block.timestamp + delay,
            beneficiary
        );

        vm.stopPrank();

        // Half of all the token are claimable after half the duration of the whole vesting
        vm.warp(startTimestamp + (delay + secondVesting) / 2);
        assertEq(vestingContract.currentlyClaimable(), amountToVest / 2);

        // All the token are claimable after the length of vesting
        vm.warp(startTimestamp + (delay + secondVesting));
        assertEq(vestingContract.currentlyClaimable(), amountToVest);
    }

    function testAddToVesting_revertIfWrongBeneficiary(address wrongBeneficiary)
        public
    {
        vm.assume(wrongBeneficiary != beneficiary);
        vm.startPrank(authorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vm.expectRevert(
            abi.encodeWithSignature(
                "JBVestingDelegation_BeneficiariesMismatch()"
            )
        );
        vestingContract.addToVesting(
            amountToVest,
            block.timestamp + 10,
            wrongBeneficiary
        );
        vm.stopPrank();
    }

    function testAddToVesting_revertIfWrongSender() public {
        vm.startPrank(unauthorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vm.expectRevert(
            abi.encodeWithSignature("JBVestingDelegation_UnauthorizedSender()")
        );
        vestingContract.addToVesting(
            amountToVest,
            block.timestamp + 10,
            beneficiary
        );
        vm.stopPrank();
    }

    function testUnvest_unvestWholeAmountAtExpiry(uint128 delay) public {
        vm.assume(delay % 2 == 0 && delay > 0); // Avoid rounding errors
        vm.startPrank(authorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vestingContract.addToVesting(
            amountToVest,
            block.timestamp + delay,
            beneficiary
        );
        vm.stopPrank();

        vm.warp(block.timestamp + delay);

        uint256 balanceBeforeUnvesting = jbxToken.balanceOf(beneficiary);
        vestingContract.unvest();
        assertEq(
            balanceBeforeUnvesting + amountToVest,
            jbxToken.balanceOf(beneficiary)
        );
    }

    function testUnvest_unvestPartially(uint128 delay) public {
        vm.assume(delay % 2 == 0 && delay > 0); // Avoid rounding errors
        vm.startPrank(authorizedSender);
        jbxToken.approve(address(vestingContract), amountToVest);

        vestingContract.addToVesting(
            amountToVest,
            block.timestamp + delay,
            beneficiary
        );
        vm.stopPrank();

        // Claim after first half of vesting period -> half of the vested amount
        vm.warp(block.timestamp + delay / 2);
        uint256 balanceBeforeUnvesting = jbxToken.balanceOf(beneficiary);
        vestingContract.unvest();
        assertEq(
            balanceBeforeUnvesting + amountToVest / 2,
            jbxToken.balanceOf(beneficiary)
        );

        // Claim after the second half/the whole vesting period -> the rest of the amount
        vm.warp(block.timestamp + delay / 2);
        balanceBeforeUnvesting = jbxToken.balanceOf(beneficiary);
        vestingContract.unvest();
        assertEq(
            balanceBeforeUnvesting + amountToVest / 2,
            jbxToken.balanceOf(beneficiary)
        );

        // Try to claim more -> nothing happens
        vestingContract.unvest();
        assertEq(
            balanceBeforeUnvesting + amountToVest / 2,
            jbxToken.balanceOf(beneficiary)
        );
    }
}
