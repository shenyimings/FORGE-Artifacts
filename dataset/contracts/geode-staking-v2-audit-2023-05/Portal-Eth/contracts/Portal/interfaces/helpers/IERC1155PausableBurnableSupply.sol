// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

interface IERC1155Burnable is IERC165, IERC1155, IERC1155MetadataURI {
  function burn(address account, uint256 id, uint256 value) external;

  function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
}

interface IERC1155Supply is IERC165, IERC1155, IERC1155MetadataURI {
  function totalSupply(uint256 id) external view returns (uint256);

  function exists(uint256 id) external view returns (bool);
}

interface IERC1155PausableBurnableSupply is IERC1155Burnable, IERC1155Supply {
  function setURI(string memory newuri) external;

  function pause() external;

  function unpause() external;

  function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external;
}
