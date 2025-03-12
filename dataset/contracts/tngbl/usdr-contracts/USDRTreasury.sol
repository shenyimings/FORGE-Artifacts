// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./constants/addresses.sol";
import "./constants/roles.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/ILiquidityManager.sol";
import "./interfaces/IRWACalculator.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/ITokenSwap.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/ITreasuryTracker.sol";
import "./interfaces/IUSDR.sol";
import "./tokens/interfaces/ITangibleERC20.sol";
import "./tangibleInterfaces/IInstantLiquidity.sol";
import "./tangibleInterfaces/ITangibleMarketplace.sol";
import "./tangibleInterfaces/ITangibleRentShare.sol";
import "./tangibleInterfaces/ITangibleRevenueShare.sol";
import "./tangibleInterfaces/ITangiblePiNFT.sol";
import "./AddressAccessor.sol";

interface ITreasuryTrackerExt is ITreasuryTracker {
    //fractions
    function getFractionContractsInTreasury()
        external
        view
        returns (address[] memory);

    function getFractionTokensInTreasury(address ftnft)
        external
        view
        returns (uint256[] memory);

    //tnfts
    function getTnftCategoriesInTreasury()
        external
        view
        returns (address[] memory);

    function getTnftTokensInTreasury(address tnft)
        external
        view
        returns (uint256[] memory);
}

contract USDRTreasury is AddressAccessor, ITreasury, IERC721Receiver {
    using SafeERC20 for IERC20;

    uint8 public incentiveThreshold;
    uint8 public tngblBurnThreshold;
    uint8 public purchaseStableMintedRedeemedThreshold;
    uint8 public purchaseStableMarketcapThreshold;

    uint256 public rebaseAmount;

    address private lastReceivedNFT;
    uint256 private lastReceivedTokenId;

    bool public emergencyStop;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        incentiveThreshold = 130;
        tngblBurnThreshold = 130;
        purchaseStableMintedRedeemedThreshold = 50;
        purchaseStableMarketcapThreshold = 10;
    }

    function setThresholds(
        uint8 _purchaseStableMintedRedeemedThreshold,
        uint8 _purchaseStableMarketcapThreshold,
        uint8 _tngblThreshold,
        uint8 _incentiveThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        purchaseStableMintedRedeemedThreshold = _purchaseStableMintedRedeemedThreshold;
        purchaseStableMarketcapThreshold = _purchaseStableMarketcapThreshold;
        tngblBurnThreshold = _tngblThreshold;
        incentiveThreshold = _incentiveThreshold;
    }

    function multicall(address[] calldata contracts, bytes[] calldata data)
        external
        onlyRole(CONTROLLER_ROLE)
        returns (bytes[] memory results)
    {
        uint256 n = contracts.length;
        results = new bytes[](n);
        for (uint256 i; i < n; i++) {
            (bool success, bytes memory result) = contracts[i].call(data[i]);
            if (success == false) {
                assembly {
                    let ptr := mload(0x40)
                    let size := returndatasize()
                    returndatacopy(ptr, 0, size)
                    revert(ptr, size)
                }
            }
            results[i] = result;
        }
        _verifyBacking(100, true);
    }

    function triggerRebase(uint256 depositAmount)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        uint256 amount = rebaseAmount + depositAmount;
        ITreasury.TreasuryValue memory value = getTreasuryValue();
        (address underlying, address usdr, address exchange) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    UNDERLYING_ADDRESS,
                    USDR_ADDRESS,
                    USDR_EXCHANGE_ADDRESS
                )
            ),
            (address, address, address)
        );
        if (depositAmount > 0) {
            try
                IERC20(underlying).transferFrom(
                    msg.sender,
                    address(this),
                    depositAmount
                )
            returns (bool success) {
                if (!success) amount = amount - depositAmount;
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                amount = amount - depositAmount;
            }
        }
        require(amount > 0);
        uint256 marketCap = IExchange(exchange).scaleToUnderlying(
            IERC20(usdr).totalSupply()
        );
        if (marketCap + amount > value.total) {
            amount = amount / 2;
        }
        IUSDR(usdr).rebase(amount);
        rebaseAmount = 0;
    }

    //workaround for purchasing initial sale RE
    function purchaseReInitialSale(
        IERC20 paymentToken,
        address ftnft,
        uint256 fractTokenId,
        uint256 share,
        uint256 ptAmount
    ) external {
        (address rePurchaseManager, address marketplace) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    RE_PURCHASE_MANAGER_ADDRESS,
                    TANGIBLE_MARKETPLACE_ADDRESS
                )
            ),
            (address, address)
        );
        require(msg.sender == rePurchaseManager, "only RePM allowed");

        paymentToken.approve(marketplace, ptAmount);
        //purchase ftnft
        ITangibleMarketplace(marketplace).buyFraction(
            ITangibleFractionsNFT(ftnft),
            fractTokenId,
            share
        );
        //update tracker
        updateTrackerFtnft(
            ftnft,
            lastReceivedTokenId,
            true,
            ptAmount,
            IERC20Metadata(address(paymentToken)).decimals()
        );
    }

    function _swapToTreasuryToken(address tokenFrom, uint256 amount)
        internal
        returns (uint256)
    {
        require(
            IERC20(tokenFrom).balanceOf(address(this)) <= amount,
            "not enough token"
        );
        (address tokenSwap, address underlying) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TOKEN_SWAP_ADDRESS, UNDERLYING_ADDRESS)
            ),
            (address, address)
        );
        uint256 amountOut = ITokenSwap(tokenSwap).quoteOut(
            tokenFrom,
            underlying,
            amount
        );
        IERC20(tokenFrom).approve(tokenSwap, amount);
        return
            ITokenSwap(tokenSwap).exchange(
                tokenFrom,
                underlying,
                amount,
                amountOut,
                ITokenSwap.EXCHANGE_TYPE.EXACT_INPUT
            );
    }

    function getTreasuryValue()
        public
        view
        returns (ITreasury.TreasuryValue memory value)
    {
        AddressHolder memory ah;
        (
            ah.calculator,
            ah.oracle,
            ah.tngbl,
            ah.underlying,
            ah.usdr,
            ah.liquidityManager,
            ah.tngblLiquidityManager,
            ah.promissory
        ) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    RWA_CALCULATOR_ADDRESS,
                    TNGBL_ORACLE_ADDRESS,
                    TNGBL_ADDRESS,
                    UNDERLYING_ADDRESS,
                    USDR_ADDRESS,
                    LIQUIDITY_MANAGER_ADDRESS,
                    TNGBL_LIQUIDITY_MANAGER_ADDRESS,
                    PROMISSORY_ADDRESS
                )
            ),
            (
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address
            )
        );
        {
            uint256 underlyingMultiplier = 10 **
                (18 - IERC20Metadata(ah.underlying).decimals());
            value.stable =
                IERC20(ah.underlying).balanceOf(address(this)) *
                underlyingMultiplier;
            value.usdr = IERC20(ah.usdr).balanceOf(address(this)) * 1e9;

            (
                value.rwa,
                value.rwaVaults,
                value.rwaEscrow,
                value.rwaValueNotLatest
            ) = IRWACalculator(ah.calculator).calculate(IERC20(ah.underlying));
            value.rwa *= underlyingMultiplier;
            value.rwaEscrow *= underlyingMultiplier;
            value.rwaVaults *= underlyingMultiplier;
        }
        {
            uint256 TNGBL = 10**IERC20Metadata(ah.tngbl).decimals();
            uint256 tngblPrice = IPriceOracle(ah.oracle).quote(TNGBL);
            value.tngbl =
                (IERC20(ah.tngbl).balanceOf(address(this)) * tngblPrice) /
                TNGBL;
            (uint256 tngblAmount, uint256 underlyingAmount) = ILiquidityManager(
                ah.tngblLiquidityManager
            ).getTokenAmounts();
            value.tngblLiquidity.tngbl = (tngblAmount * tngblPrice) / TNGBL;
            value.tngblLiquidity.underlying = underlyingAmount;
            value.tngblLiquidity.liquidity =
                value.tngblLiquidity.tngbl +
                underlyingAmount;
        }
        value.liquidity = ILiquidityManager(ah.liquidityManager).liquidity();
        value.debt =
            IERC20(ah.promissory).totalSupply() *
            (10**(18 - IERC20Metadata(ah.promissory).decimals()));
        value.total =
            value.stable +
            value.usdr +
            value.rwa +
            value.tngbl +
            value.liquidity +
            value.tngblLiquidity.liquidity +
            value.rwaVaults +
            value.rwaEscrow;
        if (value.debt < value.total) value.total = value.total - value.debt;
        else value.total = 0;
    }

    function withdraw(
        address stableToken,
        uint256 amount,
        address receiver
    ) external override validToken(stableToken) {
        (address usdrExchange, address promissory) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(USDR_EXCHANGE_ADDRESS, PROMISSORY_ADDRESS)
            ),
            (address, address)
        );
        require(
            msg.sender == usdrExchange || msg.sender == promissory,
            "not allowed"
        );
        IERC20(stableToken).safeTransfer(receiver, amount);
    }

    //add fraction storage payment!!!!!!!

    function defractionalize(
        ITangibleFractionsNFT ftnft,
        uint256[] memory tokenIds
    ) external onlyRole(CONTROLLER_ROLE) {
        ftnft.defractionalize(tokenIds);
        uint256 length = tokenIds.length;
        ITreasuryTracker tracker = ITreasuryTracker(
            _fetchAddress(TREASURY_TRACKER_ADDRESS)
        );
        for (uint256 i = 1; i < length; i++) {
            tracker.ftnftTreasuryPlaced(address(ftnft), tokenIds[i], false);
        }
        // the last received nft is the one underlying in ftnft
        if (
            (lastReceivedNFT == address(ftnft.tnft())) &&
            (lastReceivedTokenId == ftnft.tnftTokenId())
        ) {
            tracker.ftnftTreasuryPlaced(address(ftnft), tokenIds[0], false);
            tracker.tnftTreasuryPlaced(
                lastReceivedNFT,
                lastReceivedTokenId,
                true
            );
        } else {
            tracker.updateFractionData(address(ftnft), tokenIds[0]);
        }
        IERC20 revenueToken = IERC20(_fetchAddress(REVENUE_TOKEN_ADDRESS));
        if (revenueToken.balanceOf(address(this)) > 0) {
            _swapToTreasuryToken(
                address(revenueToken),
                revenueToken.balanceOf(address(this))
            );
        }
    }

    function updateTrackerFtnftExt(
        address ftnft,
        uint256 tokenId,
        bool placed
    ) external onlyRole(TRACKER_ROLE) {
        updateTrackerFtnft(ftnft, tokenId, placed, 0, 0);
    }

    function updateTrackerFtnft(
        address ftnft,
        uint256 tokenId,
        bool placed,
        uint256 ptAmount,
        uint8 ptDecimals
    ) internal {
        AddressHolder memory ah;
        (ah.tracker, ah.calculator, ah.marketplace) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    TREASURY_TRACKER_ADDRESS,
                    RWA_CALCULATOR_ADDRESS,
                    TANGIBLE_MARKETPLACE_ADDRESS
                )
            ),
            (address, address, address)
        );
        ITreasuryTracker(ah.tracker).ftnftTreasuryPlaced(
            ftnft,
            tokenId,
            placed
        );
        (string memory currency, uint256 value) = IRWACalculator(ah.calculator)
            .calcFractionNativeValue(
                ftnft,
                ITangibleFractionsNFT(ftnft).fractionShares(tokenId)
            );
        IFactoryExt factory = ITangibleMarketplace(ah.marketplace).factory();
        placed
            ? ITreasuryTracker(ah.tracker).addValueAfterPurchase(
                currency,
                value,
                factory
                    .fractionToTnftAndId(ITangibleFractionsNFT(ftnft))
                    .initialSaleDone,
                ptAmount,
                ptDecimals
            )
            : ITreasuryTracker(ah.tracker).subValueAfterPurchase(
                currency,
                value
            );
    }

    function updateTrackerTnftExt(
        address tnft,
        uint256 tokenId,
        bool placed
    ) external onlyRole(TRACKER_ROLE) {
        updateTrackerTnft(tnft, tokenId, placed);
    }

    function updateTrackerTnft(
        address tnft,
        uint256 tokenId,
        bool placed
    ) internal {
        (address tracker, address rwaCalculator) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_TRACKER_ADDRESS, RWA_CALCULATOR_ADDRESS)
            ),
            (address, address)
        );
        ITreasuryTracker(tracker).tnftTreasuryPlaced(tnft, tokenId, placed);
        (string memory currency, uint256 value) = IRWACalculator(rwaCalculator)
            .calcTnftNativeValue(
                tnft,
                ITangibleNFT(tnft).tokensFingerprint(tokenId)
            );
        placed
            ? ITreasuryTracker(tracker).addValueAfterPurchase(
                currency,
                value,
                true,
                0,
                0
            )
            : ITreasuryTracker(tracker).subValueAfterPurchase(currency, value);
    }

    function toggleStop() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (emergencyStop) {
            emergencyStop = false;
        } else {
            emergencyStop = true;
        }
    }

    function withdrawToken(address token)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        (address underlying, address tngbl) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(UNDERLYING_ADDRESS, TNGBL_ADDRESS)
            ),
            (address, address)
        );
        if (token == tngbl || token == underlying) {
            require(emergencyStop, "emergency stop required");
        }
        IERC20(token).safeTransfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    function withdrawDepositNFT(
        address _nft,
        uint256[] calldata _tokenIds,
        bool ftnft,
        bool depositing
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _withdrawDepositNFT(_nft, _tokenIds, ftnft, depositing);
    }

    function _withdrawDepositNFT(
        address _nft,
        uint256[] calldata _tokenIds,
        bool ftnft,
        bool depositing
    ) internal {
        require(emergencyStop, "emergency stop required");
        uint256 length = _tokenIds.length;

        for (uint256 i; i < length; i++) {
            depositing //send to treasury
                ? IERC721(_nft).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _tokenIds[i]
                ) //send to caller
                : IERC721(_nft).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _tokenIds[i]
                );
            if (!ftnft) {
                updateTrackerTnft(
                    _nft,
                    _tokenIds[i],
                    depositing ? true : false
                );
            } else {
                updateTrackerFtnft(
                    _nft,
                    _tokenIds[i],
                    depositing ? true : false,
                    0,
                    0
                );
            }
        }
    }

    function claimRentForToken(
        address revenueShare,
        address contractAddress,
        uint256 tokenId
    ) external onlyRole(CONTROLLER_ROLE) {
        address revenueToken = ITangibleRevenueShare(revenueShare)
            .revenueToken();
        uint256 balanceBefore = IERC20(revenueToken).balanceOf(address(this));
        ITangibleRevenueShare(revenueShare).claimForToken(
            contractAddress,
            tokenId
        );
        uint256 claimedAmount = IERC20(revenueToken).balanceOf(address(this)) -
            balanceBefore;
        rebaseAmount += _swapToTreasuryToken(revenueToken, claimedAmount);

        emit RentClaimed(revenueToken, claimedAmount);
    }

    function claimTngblRevenue(
        address contractAddress,
        uint256 tokenId,
        bool fraction
    ) external {
        (address revenueShare, address piNft, address tngbl) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    TANGIBLE_REVENUE_SHARE_ADDRESS,
                    TANGIBLE_PINFT_ADDRESS,
                    TNGBL_ADDRESS
                )
            ),
            (address, address, address)
        );
        //rev data
        address revenueToken = ITangibleRevenueShare(revenueShare)
            .revenueToken();
        uint256 balanceBeforeRevToken = IERC20(revenueToken).balanceOf(
            address(this)
        );
        //tngbl data
        uint256 balanceBeforeTngblToken = IERC20(tngbl).balanceOf(
            address(this)
        );
        // claim tngbl first
        if (!fraction) {
            // it is TNFT
            (uint256 free, ) = ITangiblePiNFT(piNft).claimableIncome(
                ITangibleNFT(contractAddress).tnftToPassiveNft(tokenId)
            );
            ITangibleNFT(contractAddress).claim(tokenId, free);
        } else {
            // it is FRACTION
            ITangibleFractionsNFT(contractAddress).claim(
                tokenId,
                ITangibleFractionsNFT(contractAddress).claimableIncome(tokenId)
            );
        }
        uint256 claimedAmountTngbl = IERC20(tngbl).balanceOf(address(this)) -
            balanceBeforeTngblToken;
        // claim revenue
        ITangibleRevenueShare(revenueShare).claimForToken(
            contractAddress,
            tokenId
        );
        uint256 claimedAmountRev = IERC20(revenueToken).balanceOf(
            address(this)
        ) - balanceBeforeRevToken;

        emit TNGBLClaimed(tngbl, claimedAmountTngbl);
        emit RevenueShareClaimed(revenueToken, claimedAmountRev);
    }

    function payFractionStorage(
        address ftnft,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(CONTROLLER_ROLE) {
        (address marketplace, address tokenSwap, address underlying) = abi
            .decode(
                addressProvider.getAddresses(
                    abi.encode(
                        TANGIBLE_MARKETPLACE_ADDRESS,
                        TOKEN_SWAP_ADDRESS,
                        UNDERLYING_ADDRESS
                    )
                ),
                (address, address, address)
            );
        IFactoryExt factory = ITangibleMarketplace(marketplace).factory();
        IFractionStorageManager manager = factory.storageManagers(
            ITangibleFractionsNFT(ftnft)
        );
        factory.defUSD().approve(address(manager), amount);

        uint256 reserveAmount = ITokenSwap(tokenSwap).quoteIn(
            underlying,
            address(factory.defUSD()),
            amount
        );

        IERC20(underlying).approve(tokenSwap, reserveAmount);
        ITokenSwap(tokenSwap).exchange(
            underlying,
            address(factory.defUSD()),
            reserveAmount,
            amount,
            ITokenSwap.EXCHANGE_TYPE.EXACT_OUTPUT
        );
        manager.payShareStorage(tokenId);
    }

    function onERC721Received(
        address, /*operator*/
        address, /*seller*/
        uint256 tokenId,
        bytes calldata /*data*/
    ) external override returns (bytes4) {
        lastReceivedNFT = msg.sender;
        lastReceivedTokenId = tokenId;
        return IERC721Receiver.onERC721Received.selector;
    }

    function _fetchAddress(bytes32 contractAddress)
        internal
        view
        returns (address)
    {
        return addressProvider.getAddress(contractAddress);
    }

    function _verifyBacking(uint8 threshold, bool includeTNGBL) internal view {
        address usdr = _fetchAddress(USDR_ADDRESS);
        ITreasury.TreasuryValue memory tv = getTreasuryValue();
        uint256 scaledMarketCap = IERC20(usdr).totalSupply() * 1e9;
        uint256 backing = tv.total;
        if (!includeTNGBL) {
            backing = backing - tv.tngbl - tv.tngblLiquidity.tngbl;
        }
        require(
            (scaledMarketCap * threshold) / 100 <= backing,
            "insufficient backing"
        );
    }

    modifier validToken(address token) {
        (address underlying, address tngbl) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(UNDERLYING_ADDRESS, TNGBL_ADDRESS)
            ),
            (address, address)
        );
        require(token == underlying || token == tngbl, "invalid token");
        _;
    }
}
