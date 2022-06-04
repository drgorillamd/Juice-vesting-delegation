// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IDelegateRegistry.sol";

/**
    @title
    Juicebox vest and delegate
    
    @notice
    Provide a linear vesting of a JB Token, while keeping the voting power via the use
    of the Gnosis Delegate Registry (used by Snapshot in its delegation strategy)

    @dev
    This vesting contract is meant to vest the token of a single entity, due to the delegation reliance on msg.sender
*/

contract JBVestingDelegation {
    error JBVestingDelegation_BeneficiariesMismatch();
    error JBVestingDelegation_UnauthorizedSender();
    error JBVestingDelegation_VestingPeriodDecrease();

    // The begining of the vesting (as an unix timestamp)
    uint256 vestingBeginning;

    // The end of the vesting period (as an unix timestamp)
    uint256 endOfVesting;

    // The vested/delegated token
    IERC20 immutable token;

    // The sole beneficiary of the vesting
    address immutable beneficiary;

    // The sender of the vested token - prevent spamming/extending the vesting period
    address immutable authorizedSender;

    constructor(
        IERC20 _token,
        IDelegateRegistry _delegateRegistry,
        address _beneficiary,
        address _authorizedSender
    ) {
        token = _token;
        beneficiary = _beneficiary;
        authorizedSender = _authorizedSender;

        // Set the beneficiary as delegate of this contract's voting power
        _delegateRegistry.setDelegate("jbdao.eth", _beneficiary);
    }

    /**
        @notice
        Add more token to the current vesting and, optionnaly, extend the vesting period

        @dev
        This contract needs to be approved by the authorized sender

        @param _amount the token amount to vest
        @param _timestampEnd the timestamp of the end of the vesting period, in Unix epoch seconds
        @param _beneficiary the beneficiary of the vesting - this is an extra check when managing multiple vesting
    */
    function addToVesting(
        uint256 _amount,
        uint256 _timestampEnd,
        address _beneficiary
    ) external {
        if (_beneficiary != beneficiary)
            revert JBVestingDelegation_BeneficiariesMismatch();

        if (msg.sender != authorizedSender)
            revert JBVestingDelegation_UnauthorizedSender();

        if (_timestampEnd < endOfVesting)
            revert JBVestingDelegation_VestingPeriodDecrease();

        if (vestingBeginning == 0) vestingBeginning = block.timestamp;

        endOfVesting = _timestampEnd;

        token.transferFrom(msg.sender, address(this), _amount);
    }

    /**
    @notice
    Unvest the amuont currently available
    
    @dev
    When unvesting during the vesting period, the reminder of the period is treated as a new vesting, with the
    rest of the contract balance, by overwriting the vestingBeginning
    */
    function unvest() external {
        uint256 claimable = currentlyClaimable();
        vestingBeginning = block.timestamp; // withdrawing during the vesting period is same as restarting a new vesting with the new balance left
        token.transfer(beneficiary, claimable);
    }

    /**
    @notice
    Compute the amount of vested token the beneficiary can currently claim.
    
    @return claimable the amount which can be unvested
    */
    function currentlyClaimable() public view returns (uint256 claimable) {
        uint256 _balance = token.balanceOf(address(this));

        if (endOfVesting > block.timestamp) {
            claimable =
                (_balance * (block.timestamp - vestingBeginning)) /
                (endOfVesting - vestingBeginning);
        } else claimable = _balance;
    }
}
