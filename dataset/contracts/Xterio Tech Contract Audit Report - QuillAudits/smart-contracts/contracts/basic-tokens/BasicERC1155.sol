// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./management/GatewayGuardedOwnable.sol";
import "./interfaces/IGateway.sol";
import "./interfaces/IBasicERC1155.sol";

import "./ERC5006.sol";

import "operator-filter-registry/src/OperatorFilterer.sol";

contract BasicERC1155 is
    IBasicERC1155,
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    ERC5006,
    GatewayGuardedOwnable,
    Pausable,
    OperatorFilterer
{
    uint256 constant VERSION = 20230120;

    /**
     * @param _gateway NFTGateway contract of the NFT contract.
     */
    constructor(
        address owner,
        string memory _uri,
        address subscriptionOrRegistrantToCopy,
        bool subscribe,
        address _gateway
    )
        ERC5006(_uri, type(uint256).max)
        GatewayGuarded(_gateway)
        OperatorFilterer(subscriptionOrRegistrantToCopy, subscribe)
    {
        _transferOwnership(owner);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external override onlyGateway {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override onlyGateway {
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(0), "{id}"));
    }

    function contractURI() public view returns (string memory) {
        return super.uri(0);
    }

    function setURI(string calldata newuri) external override onlyGateway {
        _setURI(newuri);
    }

    // These functions are overriden for the operator filterer to work
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function isApprovedForAll(
        address account,
        address operator
    ) public view override returns (bool) {
        if (IGateway(gateway).operatorWhitelist(operator)) {
            return true;
        }
        return super.isApprovedForAll(account, operator);
    }

    function pause() external onlyGateway {
        _pause();
    }

    function unpause() external onlyGateway {
        _unpause();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, ERC5006) returns (bool) {
        return
            interfaceId == type(IBasicERC1155).interfaceId ||
            ERC5006.supportsInterface(interfaceId);
    }
}
