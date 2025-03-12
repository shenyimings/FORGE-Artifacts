pragma solidity 0.7.4;
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

/**
 * @notice Keep track of players participation in Conquest and used to issue rewards.
 * @dev This contract must be at least a TIER 1 owner of the silverCardFactory and
 *      goldCardFactory.
 */
interface IConquest is IERC1155TokenReceiver {

  /***********************************|
  |         Minting Functions         |
  |__________________________________*/

  /**
   * @notice Will exit user from conquest and mint tokens to user 
   * @param _user      The address that exits conquest and receive the rewards
   * @param _silverIds Ids of silver cards to mint (duplicate ids if amount > 1)
   * @param _goldIds   Ids of gold cards to mint (duplicate ids if amount > 1)
   */
  function exitConquest(address _user, uint256[] calldata _silverIds, uint256[] calldata _goldIds) external;

  /***********************************|
  |           View Functions          |
  |__________________________________*/

  // Whether a given player is currently in a conquest
  function isActiveConquest(address _user) external view returns (bool);

  // Number of conquest a given player has entered so far
  function conquestsEntered(address _user) external view returns (uint256);

  /**
   * @notice Indicates whether a contract implements a given interface.
   * @param interfaceID The ERC-165 interface ID that is queried for support.
   * @return True if contract interface is supported.
   */
  function supportsInterface(bytes4 interfaceID) external pure returns (bool);
}
