pragma solidity 0.7.4;

import "../utils/TieredOwnable.sol";
import "../interfaces/ISkyweaverAssets.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

/**
 * @notice Allows players to buy off-chain conquest tickets via burning silver cards, 
 *         on-chain tickets or sending USDC
 */
contract ConquestPayment is IERC1155TokenReceiver, TieredOwnable {
  
  /***********************************|
  |             Variables             |
  |__________________________________*/

  // Assets
  ISkyweaverAssets immutable public skyweaverAssets; // ERC-1155 Skyweaver items contract
  uint256 immutable public conquestEntryID;          // Conquest entry token id
  uint256 immutable public silverRangeMin;           // Lower bound for the range of items IDs that can be converted to entries
  uint256 immutable public silverRangeMax;           // Upper bound for the range of items IDs that can be converted to entries

  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Create factory, link skyweaver items and store initial parameters
   * @param _firstOwner             Address of the first owner
   * @param _skyweaverAssetsAddress The address of the ERC-1155 Assets Token contract
   * @param _conquestEntryTokenId   ID of conquest ticket
   * @param _silverRangeMin         Minimum id for silver cards
   * @param _silverRangeMax         Maximum id for silver cards
   */
  constructor(
    address _firstOwner,
    address _skyweaverAssetsAddress,
    uint256 _conquestEntryTokenId,
    uint256 _silverRangeMin,
    uint256 _silverRangeMax
  ) TieredOwnable(_firstOwner) 
  {
    require(
      _skyweaverAssetsAddress != address(0) && 
      _silverRangeMin < _silverRangeMax,
      "ConquestPayment#constructor: INVALID_INPUT"
    );

    // Assets
    skyweaverAssets = ISkyweaverAssets(_skyweaverAssetsAddress);
    conquestEntryID = _conquestEntryTokenId;
    silverRangeMin = _silverRangeMin;
    silverRangeMax = _silverRangeMax;
  }

  
  /***********************************|
  |      Receiver Method Handler      |
  |__________________________________*/

  /**
   * @notice Prevents receiving Ether or calls to unsuported methods
   */
  fallback () external {
    revert("ConquestPayment#_: UNSUPPORTED_METHOD");
  }

  /**
   * @notice Players converting silver cards to conquest entries
   * @dev Payload is passed to and verified by onERC1155BatchReceived()
   */
  function onERC1155Received(
    address _operator,
    address _from,
    uint256 _id, 
    uint256 _amount, 
    bytes calldata _data
  )
    external override returns(bytes4)
  {
    // Convert payload to arrays to pass to onERC1155BatchReceived()
    uint256[] memory ids = new uint256[](1);
    uint256[] memory amounts = new uint256[](1);
    ids[0] = _id;
    amounts[0] = _amount;

    // Will revert call if doesn't pass
    onERC1155BatchReceived(_operator, _from, ids, amounts, _data);
    
    // Return success
    return IERC1155TokenReceiver.onERC1155Received.selector;
  }

  /**
   * @notice Players paying for conquest tickets with silvers or USDC
   * @param _ids     An array containing ids of each Token being transferred
   * @param _amounts An array containing amounts of each Token being transferred
   * @param _data    If data is provided, it should be address who will receive the entries
   */
  function onERC1155BatchReceived(
    address, // _operator
    address, // _from
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data
  )
    public override returns(bytes4)
  { 
    // Burn cards or ticket
    if (msg.sender == address(skyweaverAssets)) {
      
      // Validate IDs (silvers and conquest tickets)
      for (uint256 i = 0; i < _ids.length; i++) {
        require(
          (silverRangeMin <= _ids[i] && _ids[i] <= silverRangeMax) || _ids[i] == conquestEntryID, 
          "ConquestPayment#onERC1155BatchReceived: ID_IS_INVALID"
        );
      }

      // Burn items received
      skyweaverAssets.batchBurn(_ids, _amounts);

    } else {
      revert("ConquestPayment#onERC1155BatchReceived: INVALID_TOKEN_ADDRESS");
    }

    // Return success
    return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
  }

  /**
   * @notice Send ERC-20 balance to recipient
   * @param _recipient Address where the currency will be sent to
   * @param _erc20     Address of ERC-20 token to transfer out
   */
  function withdrawERC20(address _recipient, address _erc20) external onlyOwnerTier(HIGHEST_OWNER_TIER) {
    require(_recipient != address(0x0), "ConquestPayment#withdrawERC20: INVALID_RECIPIENT");
    uint256 this_balance = IERC20(_erc20).balanceOf(address(this));
    IERC20(_erc20).transfer(_recipient, this_balance);
  }


  /***********************************|
  |         Utility Functions         |
  |__________________________________*/

  /**
   * @notice Indicates whether a contract implements a given interface.
   * @param interfaceID The ERC-165 interface ID that is queried for support.
   * @return True if contract interface is supported.
   */
  function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
    return  interfaceID == type(IERC165).interfaceId || 
      interfaceID == type(IERC1155TokenReceiver).interfaceId;
  }
}