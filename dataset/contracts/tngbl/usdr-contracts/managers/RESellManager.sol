// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../constants/addresses.sol";
import "../constants/roles.sol";
import "../interfaces/ITokenSwap.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITreasuryTracker.sol";
import "../interfaces/IRWACalculator.sol";
import "../tangibleInterfaces/ITangibleMarketplace.sol";
import "../tangibleInterfaces/IInstantLiquidity.sol";
import "../tokens/interfaces/ITangibleERC20.sol";
import "./OnSaleTracker.sol";

contract ReSellManager is OnSaleTracker, IERC721Receiver {
    using SafeERC20 for IERC20;

    address private latestReceivedNFT;
    uint256 private latestReceivedToken;
    address public reTnft;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setRETnft(address tnft) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reTnft = tnft;
    }

    function sellTnft(
        IERC20 paymentToken,
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external onlyRole(CONTROLLER_ROLE) {
        address treasury = addressProvider.getAddress(TREASURY_ADDRESS);

        address[] memory contracts = new address[](3);
        bytes[] memory data = new bytes[](3);

        contracts[0] = contracts[2] = reTnft;
        contracts[1] = address(this);

        data[0] = abi.encodePacked(
            IERC721.setApprovalForAll.selector,
            abi.encode(address(this), true)
        );
        data[2] = abi.encodePacked(
            IERC721.setApprovalForAll.selector,
            abi.encode(address(this), false)
        );
        data[1] = abi.encodeWithSelector(
            ReSellManager.sellTnftCb.selector,
            paymentToken,
            tokenIds,
            prices
        );

        //update records
        ITreasury(treasury).multicall(contracts, data);
    }

    function sellTnftCb(
        IERC20 paymentToken,
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external {
        (address marketplace, address treasury) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TANGIBLE_MARKETPLACE_ADDRESS, TREASURY_ADDRESS)
            ),
            (address, address)
        );
        require(msg.sender == treasury, "not invoked by treasury");

        uint256 length = tokenIds.length;
        for (uint256 i; i < length; i++) {
            IERC721(reTnft).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
            IERC721(reTnft).approve(marketplace, tokenIds[i]);
            ITreasury(treasury).updateTrackerTnftExt(
                reTnft,
                tokenIds[i],
                false
            );
            //update local tracking mechanism so that we can use it in RWACalculator
            tnftSalePlaced(ITangibleNFT(reTnft), tokenIds[i], true);
        }

        ITangibleMarketplace(marketplace).sellBatch(
            ITangibleNFT(reTnft),
            paymentToken,
            tokenIds,
            prices
        );
    }

    function modifyTnftSale(
        address tnft,
        uint256[] memory tokenIds,
        uint256[] memory prices
    ) external onlyRole(CONTROLLER_ROLE) {
        //put on sale
        address marketplace = addressProvider.getAddress(
            TANGIBLE_MARKETPLACE_ADDRESS
        );
        ITangibleMarketplace.Lot memory lot = ITangibleMarketplace(marketplace)
            .marketplace(tnft, tokenIds[0]);

        ITangibleMarketplace(marketplace).sellBatch(
            ITangibleNFT(tnft),
            lot.paymentToken,
            tokenIds,
            prices
        );
    }

    function sellFtnft(
        address ftnft,
        IERC20 paymentToken,
        uint256[] calldata shares,
        uint256 tokenId,
        uint256 price,
        uint256 minPurchaseShare
    ) external onlyRole(CONTROLLER_ROLE) {
        address treasury = addressProvider.getAddress(TREASURY_ADDRESS);

        require(
            reTnft == _fetchReAddressFromFraction(ftnft),
            "fraction is not re!!"
        );

        address[] memory contracts = new address[](2);
        bytes[] memory data = new bytes[](2);

        contracts[0] = ftnft;
        contracts[1] = address(this);

        data[0] = abi.encodePacked(
            IERC721.approve.selector,
            abi.encode(address(this), tokenId)
        );
        data[1] = abi.encodeWithSelector(
            ReSellManager.sellFtnftCb.selector,
            ftnft,
            paymentToken,
            shares,
            tokenId,
            price,
            minPurchaseShare
        );

        //update records
        ITreasury(treasury).multicall(contracts, data);
    }

    function sellFtnftCb(
        address ftnft,
        IERC20 paymentToken,
        uint256[] calldata shares,
        uint256 tokenId,
        uint256 price,
        uint256 minPurchaseShare
    ) external {
        (address marketplace, address treasury) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TANGIBLE_MARKETPLACE_ADDRESS, TREASURY_ADDRESS)
            ),
            (address, address)
        );
        require(msg.sender == treasury, "not invoked by treasury");
        //take it from treasury
        IERC721(ftnft).safeTransferFrom(treasury, address(this), tokenId);
        //update tracker correctly
        if (ITangibleFractionsNFT(ftnft).fractionShares(tokenId) == shares[0]) {
            ITreasury(treasury).updateTrackerFtnftExt(ftnft, tokenId, false);
            //update local tracking mechanism so that we can use it in RWACalculator
            ftnftSalePlaced(ITangibleFractionsNFT(ftnft), tokenId, true);
        } else {
            // we are not selling everything
            ITreasuryTracker(treasury).updateFractionData(
                address(ftnft),
                tokenId
            );
        }
        //approve
        IERC721(ftnft).approve(marketplace, tokenId);
        //put on sale
        ITangibleMarketplace(marketplace).sellFraction(
            ITangibleFractionsNFT(ftnft),
            paymentToken,
            tokenId,
            shares,
            price,
            minPurchaseShare
        );
    }

    function modifyFtnftSale(
        address ftnft,
        uint256 tokenId,
        uint256 price,
        uint256 minPurchaseShare
    ) external onlyRole(CONTROLLER_ROLE) {
        //put on sale
        address marketplace = addressProvider.getAddress(
            TANGIBLE_MARKETPLACE_ADDRESS
        );
        ITangibleMarketplace.LotFract memory lf = ITangibleMarketplace(
            marketplace
        ).marketplaceFract(ftnft, tokenId);
        uint256[] memory shares = new uint256[](2);

        ITangibleMarketplace(marketplace).sellFraction(
            ITangibleFractionsNFT(ftnft),
            lf.paymentToken,
            tokenId,
            shares,
            price,
            minPurchaseShare
        );
    }

    function sellFtnftInitial(
        IERC20 paymentToken,
        uint256 keepShare,
        uint256 sellShare,
        uint256 tokenId,
        uint256 sellSharePrice,
        uint256 minPurchaseShare
    ) external onlyRole(CONTROLLER_ROLE) {
        address treasury = addressProvider.getAddress(TREASURY_ADDRESS);

        address[] memory contracts = new address[](2);
        bytes[] memory data = new bytes[](2);

        contracts[0] = reTnft;
        contracts[1] = address(this);

        data[0] = abi.encodePacked(
            IERC721.approve.selector,
            abi.encode(address(this), tokenId)
        );
        data[1] = abi.encodeWithSelector(
            ReSellManager.sellFtnftInitialCb.selector,
            paymentToken,
            keepShare,
            sellShare,
            tokenId,
            sellSharePrice,
            minPurchaseShare
        );

        ITreasury(treasury).multicall(contracts, data);
    }

    function sellFtnftInitialCb(
        IERC20 paymentToken,
        uint256 keepShare,
        uint256 sellShare,
        uint256 tokenId,
        uint256 sellSharePrice,
        uint256 minPurchaseShare
    ) external {
        (address marketplace, address treasury) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TANGIBLE_MARKETPLACE_ADDRESS, TREASURY_ADDRESS)
            ),
            (address, address)
        );
        require(msg.sender == treasury, "not invoked by treasury");

        IERC721(reTnft).safeTransferFrom(treasury, address(this), tokenId);
        IERC721(reTnft).approve(marketplace, tokenId);
        ITangibleMarketplace(marketplace).sellFractionInitial(
            ITangibleNFT(reTnft),
            paymentToken,
            tokenId,
            keepShare,
            sellShare,
            sellSharePrice,
            minPurchaseShare
        );
        ITreasury(treasury).updateTrackerTnftExt(reTnft, tokenId, false);
        if (keepShare != 0) {
            ITreasury(treasury).updateTrackerFtnftExt(
                latestReceivedNFT,
                latestReceivedToken,
                true
            );
        }
    }

    function stopSellFtnft(address ftnft, uint256 tokenId)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        require(
            reTnft == _fetchReAddressFromFraction(ftnft),
            "fraction is not re!!"
        );
        (address marketplace, address treasury) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TANGIBLE_MARKETPLACE_ADDRESS, TREASURY_ADDRESS)
            ),
            (address, address)
        );
        ITangibleMarketplace(marketplace).stopFractSale(
            ITangibleFractionsNFT(ftnft),
            tokenId
        );
        //update records
        IERC721(ftnft).safeTransferFrom(address(this), treasury, tokenId);
        ITreasury(treasury).updateTrackerFtnftExt(ftnft, tokenId, true);
        //update local tracking mechanism so that we can use it in RWACalculator
        ftnftSalePlaced(ITangibleFractionsNFT(ftnft), tokenId, false);
    }

    function stopSellTnft(uint256[] calldata tokenIds)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        (address marketplace, address treasury) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TANGIBLE_MARKETPLACE_ADDRESS, TREASURY_ADDRESS)
            ),
            (address, address)
        );
        uint256 length = tokenIds.length;
        ITangibleMarketplace(marketplace).stopBatchSale(
            ITangibleNFT(reTnft),
            tokenIds
        );
        //update records
        for (uint256 i = 0; i < length; i++) {
            IERC721(reTnft).safeTransferFrom(
                address(this),
                treasury,
                tokenIds[i]
            );
            ITreasury(treasury).updateTrackerTnftExt(reTnft, tokenIds[i], true);
            //update local tracking mechanism so that we can use it in RWACalculator
            tnftSalePlaced(ITangibleNFT(reTnft), tokenIds[i], false);
        }
    }

    function _fetchReAddressFromFraction(address ftnft)
        internal
        view
        returns (address reAddress)
    {
        address marketplace = addressProvider.getAddress(
            TANGIBLE_MARKETPLACE_ADDRESS
        );
        IFactoryExt factory = ITangibleMarketplace(marketplace).factory();
        reAddress = address(
            factory.fractionToTnftAndId(ITangibleFractionsNFT(ftnft)).tnft
        );
    }

    function withdrawToken(IERC20 token) external {
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender) &&
            !hasRole(CONTROLLER_ROLE, msg.sender)
        ) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(msg.sender), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32),
                        " or ",
                        Strings.toHexString(uint256(CONTROLLER_ROLE), 32)
                    )
                )
            );
        }
        (address underlying, address tngbl) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(UNDERLYING_ADDRESS, TNGBL_ADDRESS)
            ),
            (address, address)
        );
        if ((address(token) == tngbl) || (address(token) == underlying)) {
            require(
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
                "tngbl and uderlying not alowed"
            );
        }
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function onERC721Received(
        address operator,
        address seller,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return _onERC721Received(operator, seller, tokenId, data);
    }

    function _onERC721Received(
        address, /*operator*/
        address, /*seller*/
        uint256 tokenId, /*tokenId*/
        bytes calldata /*data*/
    ) private returns (bytes4) {
        latestReceivedNFT = msg.sender;
        latestReceivedToken = tokenId;
        return IERC721Receiver.onERC721Received.selector;
    }
}
