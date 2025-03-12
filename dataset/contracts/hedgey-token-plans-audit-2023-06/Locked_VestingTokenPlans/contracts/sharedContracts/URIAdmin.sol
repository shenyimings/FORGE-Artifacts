// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

contract URIAdmin {
    /// @dev baseURI is the URI directory where the metadata is stored
  string public baseURI;
  /// @dev bool to ensure uri has been set before admin can be deleted
  bool internal uriSet;
  /// @dev admin for setting the baseURI;
  address internal uriAdmin;

  /// @notice event for when a new URI is set for the NFT metadata linking
  event URISet(string newURI);

  /// @notice event for when the URI admin is deleted
  event URIAdminDeleted(address _admin);


  /// @notice function to set the base URI after the contract has been launched, only the admin can call
  /// @param _uri is the new baseURI for the metadata
  function updateBaseURI(string memory _uri) external {
    require(msg.sender == uriAdmin, '!ADMIN');
    baseURI = _uri;
    uriSet = true;
    emit URISet(_uri);
  }

  /// @notice function to delete the admin once the uri has been set
  function deleteAdmin() external {
    require(msg.sender == uriAdmin, '!ADMIN');
    require(uriSet, '!SET');
    delete uriAdmin;
    emit URIAdminDeleted(msg.sender);
  }
}