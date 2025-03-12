// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../../interfaces/gov/ERC721/powers/IERC721Power.sol";

import "../../../libs/math/MathHelper.sol";
import "../../../libs/utils/TokenBalance.sol";

import "../../../core/Globals.sol";

abstract contract AbstractERC721Power is
    IERC721Power,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;
    using MathHelper for uint256;
    using DecimalsConverter for *;
    using TokenBalance for address;

    uint64 public powerCalcStartTimestamp;

    address public collateralToken;
    uint256 public reductionPercent;
    uint256 public totalRawPower;

    uint256 public nftMaxRawPower;
    uint256 public nftRequiredCollateral;

    mapping(uint256 => NftInfo) internal _nftInfos; // tokenId => info

    modifier onlyBeforePowerCalc() {
        _onlyBeforePowerCalc();
        _;
    }

    function __AbstractERC721Power_init(
        string memory name,
        string memory symbol,
        uint64 startTimestamp,
        address _collateralToken,
        uint256 _reductionPercent,
        uint256 _nftMaxRawPower,
        uint256 _nftRequiredCollateral
    ) internal onlyInitializing {
        __Ownable_init();
        __ERC721_init(name, symbol);

        require(_collateralToken != address(0), "ERC721Power: zero address");
        require(_nftMaxRawPower > 0, "ERC721Power: max power can't be zero");
        require(_reductionPercent > 0, "ERC721Power: reduction percent can't be zero");
        require(_reductionPercent < PERCENTAGE_100, "ERC721Power: reduction can't be 100%");
        require(
            _nftRequiredCollateral > 0,
            "ERC721Power: required collateral amount can't be zero"
        );

        powerCalcStartTimestamp = startTimestamp;

        collateralToken = _collateralToken;
        reductionPercent = _reductionPercent;

        nftMaxRawPower = _nftMaxRawPower;
        nftRequiredCollateral = _nftRequiredCollateral;
    }

    function setNftMaxRawPower(
        uint256 _nftMaxRawPower,
        uint256 tokenId
    ) external onlyOwner onlyBeforePowerCalc {
        require(_nftMaxRawPower > 0, "ERC721Power: max power can't be zero");

        if (_exists(tokenId)) {
            totalRawPower -= _getRawNftMaxPower(tokenId);
            totalRawPower += _nftMaxRawPower;
        }

        _nftInfos[tokenId].maxRawPower = _nftMaxRawPower;
    }

    function setNftRequiredCollateral(
        uint256 amount,
        uint256 tokenId
    ) external onlyOwner onlyBeforePowerCalc {
        require(amount > 0, "ERC721Power: required collateral amount can't be zero");

        _nftInfos[tokenId].requiredCollateral = amount;
    }

    function mint(
        address to,
        uint256 tokenId,
        string calldata uri_
    ) external onlyOwner onlyBeforePowerCalc {
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri_);

        totalRawPower += _getRawNftMaxPower(tokenId);
    }

    function setTokenURI(uint256 tokenId, string calldata uri_) external onlyOwner {
        _setTokenURI(tokenId, uri_);
    }

    function getNftMaxPower(uint256 tokenId) public view virtual returns (uint256);

    function getNftMinPower(uint256 tokenId) public view virtual returns (uint256);

    function getNftPower(uint256 tokenId) public view virtual returns (uint256);

    function getNftInfo(uint256 tokenId) external view virtual returns (NftInfoView memory info) {
        info.rawInfo = _nftInfos[tokenId];

        info.maxPower = getNftMaxPower(tokenId);
        info.minPower = getNftMinPower(tokenId);
        info.currentPower = getNftPower(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Power).interfaceId || super.supportsInterface(interfaceId);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        ERC721URIStorageUpgradeable._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721EnumerableUpgradeable, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        _recalculateRawNftPower(tokenId);
    }

    function _addCollateral(uint256 amount, uint256 tokenId) internal {
        require(ownerOf(tokenId) == msg.sender, "ERC721Power: sender isn't an nft owner");
        require(amount > 0, "ERC721Power: wrong collateral amount");

        IERC20(collateralToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount.from18Safe(collateralToken)
        );

        _recalculateRawNftPower(tokenId);

        _nftInfos[tokenId].currentCollateral += amount;
    }

    function _removeCollateral(uint256 amount, uint256 tokenId) internal {
        require(ownerOf(tokenId) == msg.sender, "ERC721Power: sender isn't an nft owner");

        NftInfo storage nftInfo = _nftInfos[tokenId];

        require(
            amount > 0 && amount <= nftInfo.currentCollateral,
            "ERC721Power: wrong collateral amount"
        );

        _recalculateRawNftPower(tokenId);

        nftInfo.currentCollateral -= amount;

        IERC20(collateralToken).safeTransfer(msg.sender, amount.from18Safe(collateralToken));
    }

    function _recalculateRawNftPower(uint256 tokenId) internal {
        if (!_isActiveNft(tokenId)) {
            return;
        }

        uint256 newPower = _getRawNftPower(tokenId);

        NftInfo storage nftInfo = _nftInfos[tokenId];

        totalRawPower -= nftInfo.lastUpdate != 0
            ? nftInfo.currentRawPower
            : _getRawNftMaxPower(tokenId);
        totalRawPower += newPower;

        nftInfo.lastUpdate = uint64(block.timestamp);
        nftInfo.currentRawPower = newPower;
    }

    function _getRawNftPower(uint256 tokenId) internal view returns (uint256) {
        if (!_isActiveNft(tokenId)) {
            return 0;
        }

        // Calculate the minimum possible power based on the collateral of the nft
        uint256 maxNftPower = _getRawNftMaxPower(tokenId);
        uint256 minNftPower = _getRawNftMinPower(tokenId);

        // Get last update and current power. Or set them to default if it is first iteration
        uint64 lastUpdate = _nftInfos[tokenId].lastUpdate;
        uint256 currentPower = _nftInfos[tokenId].currentRawPower;

        if (lastUpdate == 0) {
            lastUpdate = powerCalcStartTimestamp;
            currentPower = maxNftPower;
        }

        // Calculate reduction amount
        uint256 powerReductionPercent = reductionPercent * (block.timestamp - lastUpdate);
        uint256 powerReduction = currentPower.min(maxNftPower.percentage(powerReductionPercent));
        uint256 newPotentialPower = currentPower - powerReduction;

        if (minNftPower <= newPotentialPower) {
            return newPotentialPower;
        }

        if (minNftPower <= currentPower) {
            return minNftPower;
        }

        return currentPower;
    }

    function _getRawNftMaxPower(uint256 tokenId) internal view returns (uint256) {
        uint256 localRawPower = _nftInfos[tokenId].maxRawPower;

        return localRawPower == 0 ? nftMaxRawPower : localRawPower;
    }

    function _getRawNftMinPower(uint256 tokenId) internal view returns (uint256) {
        if (!_isActiveNft(tokenId)) {
            return 0;
        }

        uint256 maxNftPower = _getRawNftMaxPower(tokenId);

        return
            maxNftPower
                .ratio(_nftInfos[tokenId].currentCollateral, _getNftRequiredCollateral(tokenId))
                .min(maxNftPower);
    }

    function _getNftRequiredCollateral(uint256 tokenId) internal view returns (uint256) {
        uint256 requiredCollateralForNft = _nftInfos[tokenId].requiredCollateral;

        return requiredCollateralForNft == 0 ? nftRequiredCollateral : requiredCollateralForNft;
    }

    function _isActiveNft(uint256 tokenId) internal view returns (bool) {
        return _exists(tokenId) && block.timestamp >= powerCalcStartTimestamp;
    }

    function _onlyBeforePowerCalc() internal view {
        require(
            block.timestamp < powerCalcStartTimestamp,
            "ERC721Power: power calculation already begun"
        );
    }

    uint256[43] private _gap;
}
