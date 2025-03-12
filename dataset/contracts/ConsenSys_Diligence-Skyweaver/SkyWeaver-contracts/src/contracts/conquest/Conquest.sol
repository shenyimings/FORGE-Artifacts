pragma solidity 0.7.4;

import "../utils/TieredOwnable.sol";
import "../interfaces/ISkyweaverAssets.sol";
import "../interfaces/IRewardFactory.sol";
import "@0xsequence/erc-1155/contracts/utils/SafeMath.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

/**
 * @notice Keep track of players participation in Conquest and used to issue rewards.
 * @dev This contract must be at least a TIER 1 owner of the silverCardFactory and
 *      goldCardFactory.
 */
contract Conquest is IERC1155TokenReceiver, TieredOwnable {
  using SafeMath for uint256;

  /***********************************|
  |             Variables             |
  |__________________________________*/

  // Parameters
  uint256 constant internal TIME_BETWEEN_CONQUESTS = 1 seconds; // Seconds that must elapse between two conquest
  uint256 constant internal ENTRIES_DECIMALS = 2;               // Amount of decimals conquest entries have
  uint256 constant internal CARDS_DECIMALS = 2;                 // Number of decimals cards have

  // Contracts
  IRewardFactory immutable public silverCardFactory; // Factory that mints Silver cards
  IRewardFactory immutable public goldCardFactory;   // Factory that mints Gold cards
  ISkyweaverAssets immutable public skyweaverAssets; // ERC-1155 Skyweaver assets contract
  uint256 immutable public conquestEntryID;          // Conquest entry token id

  // Mappings
  mapping(address => bool) public isActiveConquest;    // Whether a given player is currently in a conquest
  mapping(address => uint256) public conquestsEntered; // Number of conquest a given player has entered so far
  mapping(address => uint256) public nextConquestTime; // Time when the next conquest can be started for players

  // Event
  event ConquestEntered(address user, uint256 nConquests);


  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Link factories and skyweaver assets, store initial parameters
   * @param _firstOwner               Address of the first owner
   * @param _skyweaverAssetsAddress   The address of the ERC-1155 Assets Token contract
   * @param _silverCardFactoryAddress The address of the Silver Card Factory
   * @param _goldCardFactoryAddress   The address of the Gold Card Factory
   * @param _conquestEntryTokenId     Conquest entry token id
   */
  constructor(
    address _firstOwner,
    address _skyweaverAssetsAddress,
    address _silverCardFactoryAddress,
    address _goldCardFactoryAddress,
    uint256 _conquestEntryTokenId
  ) TieredOwnable(_firstOwner) public 
  {
    require(
      _skyweaverAssetsAddress != address(0) &&
      _silverCardFactoryAddress != address(0) &&
      _goldCardFactoryAddress != address(0),
      "Conquest#constructor: INVALID_INPUT"
    );

    // Store parameters
    skyweaverAssets = ISkyweaverAssets(_skyweaverAssetsAddress);
    silverCardFactory = IRewardFactory(_silverCardFactoryAddress);
    goldCardFactory = IRewardFactory(_goldCardFactoryAddress);
    conquestEntryID = _conquestEntryTokenId;
  }

  
  /***********************************|
  |      Receiver Method Handler      |
  |__________________________________*/

  /**
   * @notice Prevents receiving Ether or calls to unsupported methods
   */
  fallback () external {
    revert("Conquest#_: UNSUPPORTED_METHOD");
  }

  /**
   * @notice Players entering conquest with conquest entry token
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
   * @notice Conquest entry point. Will mark user as having entered conquest if valid entry.
   * @param _from    Address who sent the token
   * @param _ids     An array containing ids of each Token being transferred
   * @param _amounts An array containing amounts of each Token being transferred
   */
  function onERC1155BatchReceived(
    address, // _operator
    address _from,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory // _data
  )
    public override returns(bytes4)
  {
    require(msg.sender == address(skyweaverAssets), "Conquest#entry: INVALID_ENTRY_TOKEN_ADDRESS");
    require(_ids.length == 1, "Conquest#entry: INVALID_IDS_ARRAY_LENGTH");
    require(_amounts.length == 1, "Conquest#entry: INVALID_AMOUNTS_ARRAY_LENGTH");
    require(_ids[0] == conquestEntryID, "Conquest#entry: INVALID_ENTRY_TOKEN_ID");
    require(_amounts[0] == 10**ENTRIES_DECIMALS, "Conquest#entry: INVALID_ENTRY_TOKEN_AMOUNT");
    require(!isActiveConquest[_from], "Conquest#entry: PLAYER_ALREADY_IN_CONQUEST");
    require(nextConquestTime[_from] <= block.timestamp, "Conquest#entry: NEW_CONQUEST_TOO_EARLY");

    // Mark player as playing
    isActiveConquest[_from] = true;
    conquestsEntered[_from] = conquestsEntered[_from].add(1);
    nextConquestTime[_from] = block.timestamp.add(TIME_BETWEEN_CONQUESTS);

    // Burn tickets
    skyweaverAssets.burn(conquestEntryID, 10**ENTRIES_DECIMALS);

    // Emit event
    emit ConquestEntered(_from, conquestsEntered[_from]);

    // Return success
    return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
  }


  /***********************************|
  |         Minting Functions         |
  |__________________________________*/

  /**
   * @notice Will exit user from conquest and mint tokens to user 
   * @param _user      The address that exits conquest and receive the rewards
   * @param _silverIds Ids of silver cards to mint (duplicate ids if amount > 1)
   * @param _goldIds   Ids of gold cards to mint (duplicate ids if amount > 1)
   */
  function exitConquest(address _user, uint256[] calldata _silverIds, uint256[] calldata _goldIds)
    external onlyOwnerTier(1)
  { 
    require(isActiveConquest[_user], "Conquest#exitConquest: USER_IS_NOT_IN_CONQUEST");

    // Mark player as not playing anymore
    isActiveConquest[_user] = false;

    // 0 win - 1 loss ===> 0 rewards
    if (_silverIds.length == 0 && _goldIds.length == 0) {
      /*  Do nothing if user didn't win any matches  */

    // 1 win - 1 loss ===> 1 Silver card
    } else if (_silverIds.length == 1 && _goldIds.length == 0) { 
      silverCardFactory.batchMint(_user, _silverIds, array(1, 10**CARDS_DECIMALS), "");

    // 2 wins - 1 loss ===> 2 silver cards
    } else if (_silverIds.length == 2 && _goldIds.length == 0) { 
      silverCardFactory.batchMint(_user, _silverIds, array(2, 10**CARDS_DECIMALS), "");

    // 3 wins - 0 loss ===> 1 Silver card and 1 Gold card
    } else if (_silverIds.length == 1 && _goldIds.length == 1) { 
      silverCardFactory.batchMint(_user, _silverIds, array(1, 10**CARDS_DECIMALS), "");
      goldCardFactory.batchMint(_user, _goldIds, array(1, 10**CARDS_DECIMALS), "");

    // Revert for any other combination
    } else {
      revert("Conquest#exitConquest: INVALID_REWARDS");
    }
  }

  /***********************************|
  |         Utility Functions         |
  |__________________________________*/

  /** 
   * @notice Will create an array of uint _value of length _length
   * @param _length Number of elements in array
   * @param _value  Value to put in array at each element
   */
  function array(uint256 _length, uint256 _value) internal pure returns (uint256[] memory) {
    uint256[] memory a = new uint256[](_length);
    for (uint256 i = 0; i < _length; i++) {
      a[i] = _value;
    }
    return a;
  }

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
