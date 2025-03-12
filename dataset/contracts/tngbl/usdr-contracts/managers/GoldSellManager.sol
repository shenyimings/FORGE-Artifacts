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

contract GoldSellManager is OnSaleTracker, IERC721Receiver {
    using SafeERC20 for IERC20;

    enum GOLD_WEIGHT {
        XAU100,
        XAU250,
        XAU500,
        XAU1000,
        OUT
    }

    address private latestReceivedNFT;
    uint256 private latestReceivedToken;
    address[4] public goldTnfts;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setGoldTnfts(address[4] memory _goldTnfts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        goldTnfts = _goldTnfts;
    }

    function sellTnft(
        GOLD_WEIGHT goldIndex,
        IERC20 paymentToken,
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external onlyRole(CONTROLLER_ROLE) {
        require(goldIndex < GOLD_WEIGHT.OUT, "no such gold");

        address[] memory contracts = new address[](3);
        bytes[] memory data = new bytes[](3);

        contracts[0] = contracts[2] = goldTnfts[uint256(goldIndex)];
        contracts[1] = address(this);

        data[0] = abi.encodePacked(
            IERC721.setApprovalForAll.selector,
            abi.encode(address(this), true)
        );
        data[1] = abi.encodePacked(
            GoldSellManager.sellTnftCb.selector,
            abi.encode(goldIndex, paymentToken, tokenIds, prices)
        );
        data[2] = abi.encodePacked(
            IERC721.setApprovalForAll.selector,
            abi.encode(address(this), false)
        );

        //update records
        address treasury = addressProvider.getAddress(TREASURY_ADDRESS);
        ITreasury(treasury).multicall(contracts, data);
    }

    function sellTnftCb(
        GOLD_WEIGHT goldIndex,
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
            IERC721(goldTnfts[uint256(goldIndex)]).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
            IERC721(goldTnfts[uint256(goldIndex)]).approve(
                marketplace,
                tokenIds[i]
            );
            ITreasury(treasury).updateTrackerTnftExt(
                goldTnfts[uint256(goldIndex)],
                tokenIds[i],
                false
            );
            //update local tracking mechanism so that we can use it in RWACalculator
            tnftSalePlaced(
                ITangibleNFT(goldTnfts[uint256(goldIndex)]),
                tokenIds[i],
                true
            );
        }

        ITangibleMarketplace(marketplace).sellBatch(
            ITangibleNFT(goldTnfts[uint256(goldIndex)]),
            paymentToken,
            tokenIds,
            prices
        );
    }

    function modifyTnftSale(
        GOLD_WEIGHT goldIndex,
        uint256[] memory tokenIds,
        uint256[] memory prices
    ) external onlyRole(CONTROLLER_ROLE) {
        require(goldIndex < GOLD_WEIGHT.OUT, "no such gold");
        //put on sale
        address marketplace = addressProvider.getAddress(
            TANGIBLE_MARKETPLACE_ADDRESS
        );
        ITangibleMarketplace.Lot memory lot = ITangibleMarketplace(marketplace)
            .marketplace(goldTnfts[uint256(goldIndex)], tokenIds[0]);

        ITangibleMarketplace(marketplace).sellBatch(
            ITangibleNFT(goldTnfts[uint256(goldIndex)]),
            lot.paymentToken,
            tokenIds,
            prices
        );
    }

    struct HelperStruct {
        address gold;
        address treasury;
        bool found;
    }

    function sellFtnft(
        address ftnft,
        IERC20 paymentToken,
        uint256[] calldata shares,
        uint256 tokenId,
        uint256 price,
        uint256 minPurchaseShare
    ) external onlyRole(CONTROLLER_ROLE) {
        HelperStruct memory hs;
        hs.treasury = addressProvider.getAddress(TREASURY_ADDRESS);

        hs.gold = _fetchGoldAddressFromFraction(ftnft);
        hs.found;
        for (uint256 i; i < 4; i++) {
            if (goldTnfts[i] == hs.gold) {
                hs.found = true;
                break;
            }
        }

        require(hs.found, "fraction is not gold!");

        address[] memory contracts = new address[](2);
        bytes[] memory data = new bytes[](2);

        contracts[0] = ftnft;
        contracts[1] = address(this);

        data[0] = abi.encodePacked(
            IERC721.approve.selector,
            abi.encode(address(this), tokenId)
        );
        data[1] = abi.encodePacked(
            GoldSellManager.sellFtnftCb.selector,
            abi.encode(
                ftnft,
                paymentToken,
                shares,
                tokenId,
                price,
                minPurchaseShare
            )
        );

        //update records
        ITreasury(hs.treasury).multicall(contracts, data);
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
        //approve
        IERC721(ftnft).approve(marketplace, tokenId);
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
        HelperStruct memory hs;
        hs.gold = _fetchGoldAddressFromFraction(ftnft);
        hs.found;
        for (uint256 i; i < 4; i++) {
            if (goldTnfts[i] == hs.gold) {
                hs.found = true;
                break;
            }
        }

        require(hs.found, "fraction is not gold!");
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
        GOLD_WEIGHT goldIndex,
        IERC20 paymentToken,
        uint256 keepShare,
        uint256 sellShare,
        uint256 tokenId,
        uint256 sellSharePrice,
        uint256 minPurchaseShare
    ) external onlyRole(CONTROLLER_ROLE) {
        require(goldIndex < GOLD_WEIGHT.OUT, "no such gold");
        address treasury = addressProvider.getAddress(TREASURY_ADDRESS);

        address[] memory contracts = new address[](2);
        bytes[] memory data = new bytes[](2);

        contracts[0] = goldTnfts[uint256(goldIndex)];
        contracts[1] = address(this);

        data[0] = abi.encodePacked(
            IERC721.approve.selector,
            abi.encode(address(this), tokenId)
        );
        data[1] = abi.encodePacked(
            GoldSellManager.sellFtnftInitialCb.selector,
            abi.encode(
                goldIndex,
                paymentToken,
                keepShare,
                sellShare,
                tokenId,
                sellSharePrice,
                minPurchaseShare
            )
        );

        ITreasury(treasury).multicall(contracts, data);
    }

    function sellFtnftInitialCb(
        GOLD_WEIGHT goldIndex,
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

        IERC721(goldTnfts[uint256(goldIndex)]).safeTransferFrom(
            treasury,
            address(this),
            tokenId
        );
        IERC721(goldTnfts[uint256(goldIndex)]).approve(marketplace, tokenId);
        ITangibleMarketplace(marketplace).sellFractionInitial(
            ITangibleNFT(goldTnfts[uint256(goldIndex)]),
            paymentToken,
            tokenId,
            keepShare,
            sellShare,
            sellSharePrice,
            minPurchaseShare
        );
        ITreasury(treasury).updateTrackerTnftExt(
            goldTnfts[uint256(goldIndex)],
            tokenId,
            false
        );
        if (keepShare != 0) {
            ITreasury(treasury).updateTrackerFtnftExt(
                latestReceivedNFT,
                latestReceivedToken,
                true
            );
        }
    }

    function _fetchGoldAddressFromFraction(address ftnft)
        internal
        view
        returns (address gold)
    {
        address marketplace = addressProvider.getAddress(
            TANGIBLE_MARKETPLACE_ADDRESS
        );
        IFactoryExt factory = ITangibleMarketplace(marketplace).factory();
        gold = address(
            factory.fractionToTnftAndId(ITangibleFractionsNFT(ftnft)).tnft
        );
    }

    function stopSellFtnft(address ftnft, uint256 tokenId)
        external
        onlyRole(CONTROLLER_ROLE)
    {
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

    function stopSellTnft(GOLD_WEIGHT goldIndex, uint256[] calldata tokenIds)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        require(goldIndex < GOLD_WEIGHT.OUT, "no such gold");
        (address marketplace, address treasury) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TANGIBLE_MARKETPLACE_ADDRESS, TREASURY_ADDRESS)
            ),
            (address, address)
        );
        uint256 length = tokenIds.length;
        ITangibleMarketplace(marketplace).stopBatchSale(
            ITangibleNFT(goldTnfts[uint256(goldIndex)]),
            tokenIds
        );
        //update records
        for (uint256 i = 0; i < length; i++) {
            IERC721(goldTnfts[uint256(goldIndex)]).safeTransferFrom(
                address(this),
                treasury,
                tokenIds[i]
            );
            ITreasury(treasury).updateTrackerTnftExt(
                goldTnfts[uint256(goldIndex)],
                tokenIds[i],
                true
            );
            //update local tracking mechanism so that we can use it in RWACalculator
            tnftSalePlaced(
                ITangibleNFT(goldTnfts[uint256(goldIndex)]),
                tokenIds[i],
                false
            );
        }
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
