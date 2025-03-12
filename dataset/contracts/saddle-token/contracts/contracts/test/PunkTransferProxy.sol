// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./ICryptoPunksMarket.sol";
import "../marketplace/interfaces/ITransferProxy.sol";

// DEPRECATED FILE
// THIS IS JUST A HELPER CONTRACT
// TO INTERFACE WITH LIVE CRYPTOPUNK MARKET

contract PunkTransferProxy is ITransferProxy, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    mapping(address => bool) operators;

    function initialize() external initializer {
        __UUPSUpgradeable_init();
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function transfer(
        LibAsset.Asset memory asset,
        address from,
        address to
    ) external override onlyOperator {
        (address token, uint256 punkIndex) = abi.decode(asset.assetType.data, (address, uint256));
        ICryptoPunksMarket punkToken = ICryptoPunksMarket(token);
        // check punk from real owner
        require(punkToken.punkIndexToAddress(punkIndex) == from, "Seller not punk owner");
        // buy punk to proxy, now proxy is owner
        punkToken.buyPunk(punkIndex);
        // Transfer ownership of a punk to buyer
        punkToken.transferPunk(to, punkIndex);
    }

    function addOperator(address operator) external onlyOwner {
        operators[operator] = true;
    }

    function removeOperator(address operator) external onlyOwner {
        operators[operator] = false;
    }

    modifier onlyOperator() {
        require(operators[_msgSender()], "OperatorRole: caller is not the operator");
        _;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
