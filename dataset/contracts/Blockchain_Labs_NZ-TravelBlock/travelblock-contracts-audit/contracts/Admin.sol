pragma solidity ^0.4.24;


/// Gives the owner the ability to transfer ownership of the contract to a new
/// address and it requires the owner of the new address to accept the transfer.
import "openzeppelin-solidity/contracts/ownership/Claimable.sol";


/// @title Admin functionality for TRVLToken.sol contracts.
contract Admin is Claimable{
    mapping(address => bool) public admins;

    event AdminAdded(address added);
    event AdminRemoved(address removed);

    /// @dev Verifies the msg.sender is a member of the admins mapping. Owner is by default an admin.
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "msg.sender is not an admin!");
        _;
    }

    /// @notice Adds a list of addresses to the admins list.
    /// @dev Requires that the msg.sender is the Owner. Emits an event on success.
    /// @param _admins The list of addresses to add to the admins mapping.
    function addAddressesToAdmins(address[] _admins) external onlyOwner {
        require(_admins.length > 0, "Cannot add an empty list to admins!");
        for (uint256 i = 0; i < _admins.length; ++i) {
            address user = _admins[i];
            require(user != address(0), "Cannot add the zero address to admins!");

            if (!admins[user]) {
                admins[user] = true;

                emit AdminAdded(user);
            }
        }
    }

    /// @notice Removes a list of addresses from the admins list.
    /// @dev Requires that the msg.sender is an Owner. It is possible for the admins list to be empty, this is a fail safe
    /// in the event the admin accounts are compromised. The owner has the ability to lockout the server access from which
    /// TravelBlock is processing payments. Emits an event on success.
    /// @param _admins The list of addresses to remove from the admins mapping.
    function removeAddressesFromAdmins(address[] _admins) external onlyOwner {
        require(_admins.length > 0, "Cannot remove an empty list to admins!");
        for (uint256 i = 0; i < _admins.length; ++i) {
            address user = _admins[i];

            if (admins[user]) {
                admins[user] = false;

                emit AdminRemoved(user);
            }
        }
    }
}
