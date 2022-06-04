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

    uint256 vestingBeginning;
    uint256 endOfVesting;
    uint256 totalWithdraw;

    IERC20 immutable token;
    address immutable beneficiary;
    address immutable authorizedSender;

    constructor(
        IERC20 _token,
        IDelegateRegistry _delegateRegistry, // 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446
        address _beneficiary,
        address _authorizedSender
    ) {
        token = _token;
        beneficiary = _beneficiary;
        authorizedSender = _authorizedSender;

        _delegateRegistry.setDelegate("jbdao.eth", _beneficiary);
    }

    function addToVesting(
        uint256 _amount,
        uint256 _timestampEnd,
        address _beneficiary
    ) external {
        if (_beneficiary != beneficiary)
            revert JBVestingDelegation_BeneficiariesMismatch();

        if (msg.sender != authorizedSender)
            revert JBVestingDelegation_UnauthorizedSender();

        if (vestingBeginning == 0) vestingBeginning = block.timestamp;

        endOfVesting = _timestampEnd;

        token.transferFrom(msg.sender, address(this), _amount);
    }

    function unvest() external {
        uint256 claimable = currentlyClaimable();
        token.transfer(beneficiary, claimable);
    }

    function currentlyClaimable() public view returns (uint256 maxWithdraw) {
        uint256 _balance = token.balanceOf(address(this));

        if (endOfVesting > block.timestamp) {
            maxWithdraw =
                (_balance * (block.timestamp - vestingBeginning)) /
                (endOfVesting - vestingBeginning);
            maxWithdraw = maxWithdraw > totalWithdraw
                ? maxWithdraw - totalWithdraw
                : 0;
        } else maxWithdraw = _balance;
    }
}
