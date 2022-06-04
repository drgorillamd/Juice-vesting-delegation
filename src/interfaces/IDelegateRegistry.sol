// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IDelegateRegistry {
    // The first key is the delegator and the second key a id.
    // The value is the address of the delegate
    function delegation(address delegator, bytes32 id)
        external
        returns (address);

    /// @dev Sets a delegate for the msg.sender and a specific id.
    ///      The combination of msg.sender and the id can be seen as a unique key.
    /// @param id Id for which the delegate should be set
    /// @param delegate Address of the delegate
    function setDelegate(bytes32 id, address delegate) external;

    /// @dev Clears a delegate for the msg.sender and a specific id.
    ///      The combination of msg.sender and the id can be seen as a unique key.
    /// @param id Id for which the delegate should be set
    function clearDelegate(bytes32 id) external;
}
