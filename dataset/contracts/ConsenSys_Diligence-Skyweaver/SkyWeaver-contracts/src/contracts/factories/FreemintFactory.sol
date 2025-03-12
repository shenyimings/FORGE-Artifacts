pragma solidity 0.7.4;

import "../utils/TieredOwnable.sol";
import "../interfaces/ISkyweaverAssets.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

/**
 * This is a contract allowing owner to mint any tokens within a given
 * range. This factory will be used to mint community related assets, special
 * event assets that are meant to be given away.
 */
contract FreemintFactory is TieredOwnable {

  // ERC-1155 Skyweaver assets contract
  ISkyweaverAssets internal skyweaverAssets;

  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Create factory & link skyweaver assets
   * @param _firstOwner Address of the first owner
   * @param _assetsAddr The address of the ERC-1155 Assets Token contract
   */
  constructor(address _firstOwner, address _assetsAddr) TieredOwnable(_firstOwner) public {
    require(
      _assetsAddr != address(0),
      "FreemintFactory#constructor: INVALID_INPUT"
    );
    skyweaverAssets = ISkyweaverAssets(_assetsAddr);
  }


  /***********************************|
  |         Minting Function          |
  |__________________________________*/

  /**
   * @notice Will mint a bundle of tokens to users
   * @param _recipients Arrays of addresses to mint _amounts of _ids
   * @param _ids        Array of Tokens ID that are minted
   * @param _amounts    Amount of Tokens id minted for each corresponding Token id in _ids
   */
  function batchMint(address[] calldata _recipients, uint256[] calldata _ids, uint256[] calldata _amounts)
    external onlyOwnerTier(1)
  {
    for (uint256 i = 0 ; i < _recipients.length; i++) {
      skyweaverAssets.batchMint(_recipients[i], _ids, _amounts, "");
    }
  }


  /***********************************|
  |          Misc Functions           |
  |__________________________________*/

  /**
   * @notice Returns the address of the  skyweaver assets contract
   */
  function getSkyweaverAssets() external view returns (address) {
    return address(skyweaverAssets);
  }

  /**
   * @notice Prevents receiving Ether, ERC-1155 or calls to unsuported methods
   */
  fallback () external {
    revert("FreemintFactory#_: UNSUPPORTED_METHOD");
  }

  /**
   * @notice Indicates whether a contract implements a given interface.
   * @param interfaceID The ERC-165 interface ID that is queried for support.
   * @return True if contract interface is supported.
   */
  function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
    return  interfaceID == type(IERC165).interfaceId;
  }
}
