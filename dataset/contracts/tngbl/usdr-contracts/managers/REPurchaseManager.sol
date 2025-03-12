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
import "../AddressAccessor.sol";
import "./PurchaseManager.sol";

contract RePurchaseManager is PurchaseManager, IERC721Receiver {
    using SafeERC20 for IERC20;

    address private latestReceivedNFT;
    uint256 private latestReceivedToken;
    address public reTnft;

    struct HelperStruct {
        address rwaCalculator;
        address treasury;
        IERC20 paymentToken;
        uint256 amount;
        uint256 amountOfPaymentToken;
        bool inRange;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setRETnft(address tnft) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reTnft = tnft;
    }

    function purchaseTnft(
        uint256 fingerprint,
        uint256 tokenId,
        uint256 _years,
        bool onlyLock
    ) external onlyRole(CONTROLLER_ROLE) {
        //check payment token and swap if necessary
        HelperStruct memory hs;
        address[] memory contracts = new address[](3);
        contracts[2] = address(this);
        (hs.rwaCalculator, hs.treasury, contracts[0]) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    RWA_CALCULATOR_ADDRESS,
                    TREASURY_ADDRESS,
                    UNDERLYING_ADDRESS
                )
            ),
            (address, address, address)
        );

        (hs.paymentToken, hs.amount, hs.inRange) = IRWACalculator(
            hs.rwaCalculator
        ).fetchPaymentTokenAndAmountTnft(
                reTnft,
                fingerprint,
                tokenId,
                _years,
                tokenId == 0 ? true : false
            );
        // take payment token
        contracts[1] = address(hs.paymentToken);
        require(hs.inRange, "price above range");
        // if treasury has paymentToken, use it
        if (hs.amount <= hs.paymentToken.balanceOf(hs.treasury)) {
            hs.amountOfPaymentToken = hs.amount;
            hs.amount = 0;
        } else {
            hs.amountOfPaymentToken = hs.paymentToken.balanceOf(hs.treasury);
            hs.amount -= hs.amountOfPaymentToken;
        }
        uint256 reserveAmount = _checkPaymentTokenAndAmountNeeded(
            hs.paymentToken,
            hs.amount
        );

        _validatePurchase(reserveAmount);

        bytes[] memory data = new bytes[](3);

        data[0] = abi.encodePacked(
            IERC20.approve.selector,
            abi.encode(address(this), reserveAmount)
        );
        data[1] = abi.encodePacked(
            IERC20.approve.selector,
            abi.encode(address(this), hs.amountOfPaymentToken)
        );
        data[2] = abi.encodePacked(
            RePurchaseManager.purchaseTnftCb.selector,
            abi.encode(
                hs.paymentToken,
                fingerprint,
                tokenId,
                _years,
                hs.amount,
                reserveAmount,
                hs.amountOfPaymentToken,
                onlyLock
            )
        );

        ITreasury(hs.treasury).multicall(contracts, data);
    }

    function purchaseTnftCb(
        IERC20 paymentToken,
        uint256 fingerprint,
        uint256 tokenId,
        uint256 _years,
        uint256 amountToFillUp,
        uint256 reserveAmount,
        uint256 amountOfPaymentToken,
        bool onlyLock
    ) external {
        (address underlying, address marketplace, address treasury) = abi
            .decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNDERLYING_ADDRESS,
                        TANGIBLE_MARKETPLACE_ADDRESS,
                        TREASURY_ADDRESS
                    )
                ),
                (address, address, address)
            );
        require(msg.sender == treasury, "not invoked by treasury");
        //take paymentToken
        paymentToken.safeTransferFrom(
            treasury,
            address(this),
            amountOfPaymentToken
        );
        //take the underlying from treasury
        if (reserveAmount > 0) {
            IERC20(underlying).safeTransferFrom(
                treasury,
                address(this),
                reserveAmount
            );
            //convert to paymentToken only reserveAmount
            _convertTreasuryTokenToPayment(
                paymentToken,
                reserveAmount,
                false,
                amountToFillUp + amountOfPaymentToken,
                amountToFillUp
            );
        } else {
            paymentToken.approve(marketplace, amountOfPaymentToken);
        }

        if (tokenId == 0) {
            ITangibleMarketplace(marketplace).buyUnminted(
                ITangibleNFT(reTnft),
                fingerprint,
                _years,
                onlyLock
            );
        } else {
            ITangibleMarketplace(marketplace).buy(
                ITangibleNFT(reTnft),
                tokenId,
                _years
            );
        }
        //send to treasury
        IERC721(reTnft).safeTransferFrom(
            address(this),
            treasury,
            latestReceivedToken
        );
        //send the remaining payment token
        if (paymentToken.balanceOf(address(this)) > 0) {
            paymentToken.safeTransfer(
                treasury,
                paymentToken.balanceOf(address(this))
            );
        }
        // update records
        ITreasury(treasury).updateTrackerTnftExt(
            reTnft,
            latestReceivedToken,
            true
        );
    }

    function purchaseFtnft(
        address ftnft,
        uint256 fractTokenId,
        uint256 share
    ) external onlyRole(CONTROLLER_ROLE) {
        HelperStruct memory hs;
        (
            address rwaCalculator,
            address treasury,
            address marketplace,
            address underlying
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        RWA_CALCULATOR_ADDRESS,
                        TREASURY_ADDRESS,
                        TANGIBLE_MARKETPLACE_ADDRESS,
                        UNDERLYING_ADDRESS
                    )
                ),
                (address, address, address, address)
            );
        (hs.paymentToken, hs.amount, hs.inRange) = IRWACalculator(rwaCalculator)
            .fetchPaymentTokenAndAmountFtnft(ftnft, fractTokenId, share);
        //we neglect inRange if it is initial sale of house
        if (
            ITangibleMarketplace(marketplace)
                .factory()
                .fractionToTnftAndId(ITangibleFractionsNFT(ftnft))
                .initialSaleDone
        ) {
            require(hs.inRange, "price above range");
        }
        // if treasury has paymentToken, use it
        if (hs.amount <= hs.paymentToken.balanceOf(treasury)) {
            hs.amountOfPaymentToken = hs.amount;
            hs.amount = 0;
        } else {
            hs.amountOfPaymentToken = hs.paymentToken.balanceOf(treasury);
            hs.amount -= hs.amountOfPaymentToken;
        }
        uint256 reserveAmount = _checkPaymentTokenAndAmountNeeded(
            hs.paymentToken,
            hs.amount
        );

        _validatePurchase(reserveAmount);

        require(
            reTnft == _fetchReAddressFromFraction(ftnft),
            "fraction is not re!!"
        );

        address[] memory contracts = new address[](3);
        bytes[] memory data = new bytes[](3);

        contracts[0] = underlying;
        contracts[1] = address(hs.paymentToken);
        contracts[2] = address(this);

        data[0] = abi.encodePacked(
            IERC20.approve.selector,
            abi.encode(address(this), reserveAmount)
        );
        data[1] = abi.encodePacked(
            IERC20.approve.selector,
            abi.encode(address(this), hs.amountOfPaymentToken)
        );
        data[2] = abi.encodePacked(
            RePurchaseManager.purchaseFtnftCb.selector,
            abi.encode(
                ftnft,
                hs.paymentToken,
                fractTokenId,
                share,
                reserveAmount,
                hs.amount,
                hs.amountOfPaymentToken
            )
        );

        ITreasury(treasury).multicall(contracts, data);
    }

    function purchaseFtnftCb(
        address ftnft,
        IERC20 paymentToken,
        uint256 fractTokenId,
        uint256 share,
        uint256 reserveAmount,
        uint256 amountToFillUp,
        uint256 amountOfPaymentToken
    ) external {
        (address underlying, address marketplace, address treasury) = abi
            .decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNDERLYING_ADDRESS,
                        TANGIBLE_MARKETPLACE_ADDRESS,
                        TREASURY_ADDRESS
                    )
                ),
                (address, address, address)
            );

        require(msg.sender == treasury, "not invoked by treasury");
        // take paymentTokenfrom treasury
        paymentToken.safeTransferFrom(
            treasury,
            address(this),
            amountOfPaymentToken
        );
        //take the underlying from treasury
        if (reserveAmount > 0) {
            IERC20(underlying).safeTransferFrom(
                treasury,
                address(this),
                reserveAmount
            );
            //convert to paymentToken
            _convertTreasuryTokenToPayment(
                paymentToken,
                reserveAmount,
                false,
                amountToFillUp + amountOfPaymentToken,
                amountToFillUp
            );
        } else {
            paymentToken.approve(marketplace, amountOfPaymentToken);
        }
        IFactoryExt factory = ITangibleMarketplace(marketplace).factory();
        //check if this ftnft is in initailSale - that means when bought
        //you can't move the token unless sale is complete
        //that is why actuall purchase must be done from
        //treasury in else branch
        if (
            factory
                .fractionToTnftAndId(ITangibleFractionsNFT(ftnft))
                .initialSaleDone
        ) {
            ITangibleMarketplace(marketplace).buyFraction(
                ITangibleFractionsNFT(ftnft),
                fractTokenId,
                share
            );

            //send to treasury
            IERC721(ftnft).safeTransferFrom(
                address(this),
                treasury,
                latestReceivedToken
            );
            //send the remaining payment token
            if (paymentToken.balanceOf(address(this)) > 0) {
                paymentToken.safeTransfer(
                    treasury,
                    paymentToken.balanceOf(address(this))
                );
            }
            //update records
            ITreasury(treasury).updateTrackerFtnftExt(
                ftnft,
                latestReceivedToken,
                true
            );
        } else {
            //send converted token back to treasury and buy it from there
            paymentToken.safeTransfer(
                treasury,
                amountToFillUp + amountOfPaymentToken
            );

            ITreasury(treasury).purchaseReInitialSale(
                paymentToken,
                ftnft,
                fractTokenId,
                share,
                amountToFillUp + amountOfPaymentToken
            );
        }
        //
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
