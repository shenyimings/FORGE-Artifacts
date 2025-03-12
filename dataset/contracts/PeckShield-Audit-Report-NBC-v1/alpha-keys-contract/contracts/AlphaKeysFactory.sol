// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import {BlockContext} from "./base/BlockContext.sol";
import {Multicall} from "./base/Multicall.sol";

import {IAlphaKeysFactory} from "./interfaces/IAlphaKeysFactory.sol";
import {AlphaKeysFactoryStorage} from "./storage/AlphaKeysFactoryStorage.sol";
import {IAlphaKeysToken} from "./interfaces/IAlphaKeysToken.sol";
import {IAlphaKeysVault} from "./interfaces/IAlphaKeysVault.sol";

import {NumberMath} from "./libraries/NumberMath.sol";
import {TokenTypes} from "./libraries/TokenTypes.sol";
import {ThreeThreeTypes} from "./libraries/ThreeThreeTypes.sol";
import {LimitOrderTypes} from "./libraries/LimitOrderTypes.sol";
import {WatchlistTypes} from "./libraries/WatchlistTypes.sol";

import {AlphaKeysTokenProxy} from "./AlphaKeysTokenProxy.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";

contract AlphaKeysFactory is
    IAlphaKeysFactory,
    BlockContext,
    Multicall,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    AlphaKeysFactoryStorage
{
    using SafeMathUpgradeable for uint256;
    using NumberMath for uint256;
    using AddressUpgradeable for address;
    //
    modifier onlyAdmin() {
        require(_msgSender() == _admin, "AKF_NA");
        _;
    }

    modifier onlyToken(address token) {
        require(token != address(0), "AKF_TZ");
        require(
            (_keysPlayers[token] != address(0) || _keysTwitters[token] > 0),
            "AKF_BT"
        );
        _;
    }

    modifier onlyPlayer(address player) {
        require(player != address(0), "AKF_PZ");
        require((_playerKeys[player] != address(0)), "AKF_BP");
        _;
    }

    modifier onlyTwitterId(uint256 twitterId) {
        require(twitterId > 0, "AKF_TZ");
        require((_twitterKeys[twitterId] != address(0)), "AKF_BTI");
        _;
    }

    modifier notContract() {
        // caller is contract
        require(!_msgSender().isContract(), "AKF_CIC");
        _;
    }

    receive() external payable {}

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        //
        _protocolFeeDestination = _msgSender();
        _protocolFeeRatio = 50000;
        _playerFeeRatio = 50000;
        _admin = _msgSender();
    }

    function getAlphaKeysTokenImplementation()
        external
        view
        override
        returns (address)
    {
        return _playerShareTokenImplementation;
    }

    function setAlphaKeysTokenImplementation(
        address playerShareTokenImplementationArg
    ) external onlyOwner {
        _playerShareTokenImplementation = playerShareTokenImplementationArg;
    }

    function setAdmin(address admin) external onlyOwner {
        _admin = admin;
    }

    function getAdmin() external view returns (address) {
        return _admin;
    }

    function setBTC(address btc) external onlyOwner {
        require(btc.isContract(), "AKF_BINC");
        _btc = btc;
    }

    function getBTC() external view override returns (address) {
        return _btc;
    }

    function setVault(address vault) external onlyOwner {
        require(vault.isContract(), "AKF_VINC");
        _vault = vault;
    }

    function getVault() external view override returns (address) {
        return _vault;
    }

    function setBTCPrice(uint256 btcPrice) external onlyOwner {
        _btcPrice = btcPrice;
    }

    function getBTCPrice() external view returns (uint256) {
        return _btcPrice;
    }

    function getPlayerKeys(address player) public view returns (address) {
        return _playerKeys[player];
    }

    function getKeysPlayer(address token) public view returns (address) {
        return _keysPlayers[token];
    }

    function getTwitterKeys(uint256 twitterId) public view returns (address) {
        return _twitterKeys[twitterId];
    }

    function getKeysTwitters(address token) public view returns (uint256) {
        return _keysTwitters[token];
    }

    function setProtocolFeeRatio(uint24 protocolFeeRatio) external onlyOwner {
        require(protocolFeeRatio < NumberMath.RATIO, "AKF_BR");
        _protocolFeeRatio = protocolFeeRatio;
    }

    function getProtocolFeeRatio() external view returns (uint24) {
        return _protocolFeeRatio;
    }

    function setPlayerFeeRatio(uint24 playerFeeRatio) external onlyOwner {
        require(playerFeeRatio < NumberMath.RATIO, "AKF_BR");
        _playerFeeRatio = playerFeeRatio;
    }

    function getPlayerFeeRatio() external view returns (uint24) {
        return _playerFeeRatio;
    }

    function getProtocolFeeDestination()
        external
        view
        override
        returns (address)
    {
        return _protocolFeeDestination;
    }

    function setProtocolFeeDestination(
        address protocolFeeDestination
    ) external onlyOwner {
        _protocolFeeDestination = protocolFeeDestination;
    }

    function getTwitterIdByPlayer(
        address player
    ) public view returns (uint256) {
        return _keysTwitters[_playerKeys[player]];
    }

    function getPlayerByTwitterId(
        uint256 twitterId
    ) public view returns (address) {
        return _keysPlayers[_twitterKeys[twitterId]];
    }

    // function requireToken(address token) internal {
    //     require(token != address(0), "AKF_TZ");
    //     require(
    //         (_keysPlayers[token] != address(0) || _keysTwitters[token] > 0),
    //         "AKF_BT"
    //     );
    // }

    // function requirePlayer(address player) internal {
    //     require(player != address(0), "AKF_PZ");
    //     require((_playerKeys[player] != address(0)), "AKF_BP");
    // }

    // for create token

    function getCreateForTwitterMessageHash(
        uint256 twitterId,
        string calldata name,
        string calldata symbol
    ) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return
            keccak256(
                abi.encode(address(this), chainId, twitterId, name, symbol)
            );
    }

    function _verifyCreateTokenSigner(
        uint256 twitterId,
        string calldata name,
        string calldata symbol,
        bytes memory signature
    ) internal view returns (address, bytes32) {
        bytes32 messageHash = getCreateForTwitterMessageHash(
            twitterId,
            name,
            symbol
        );
        address signer = ECDSAUpgradeable.recover(
            ECDSAUpgradeable.toEthSignedMessageHash(messageHash),
            signature
        );
        // GP_NA: Signer Is Not ADmin
        require(signer == _admin, "AKF_NA");
        return (signer, messageHash);
    }

    function createAlphaKeysForV2(
        uint256 twitterId,
        address player,
        string calldata name,
        string calldata symbol
    ) external nonReentrant onlyAdmin {
        require(twitterId > 0, "AKF_TZV");
        require(_playerKeys[player] == address(0), "AKF_PNZA");
        require(_twitterKeys[twitterId] == address(0), "AKF_TNZA");
        //
        IAlphaKeysToken token = IAlphaKeysToken(
            address(new AlphaKeysTokenProxy())
        );
        token.initialize(address(this), player, name, symbol);
        //
        _playerKeys[player] = address(token);
        _keysPlayers[address(token)] = player;
        _twitterKeys[twitterId] = address(token);
        _keysTwitters[address(token)] = twitterId;
        //
        emit AlphaKeysCreatedV2(player, address(token), twitterId);
    }

    function createAlphaKeysForTwitter(
        uint256 twitterId,
        string calldata name,
        string calldata symbol,
        bytes memory signature
    ) external notContract nonReentrant {
        require(_twitterKeys[twitterId] == address(0), "AKF_TNZA");
        _verifyCreateTokenSigner(twitterId, name, symbol, signature);
        //
        IAlphaKeysToken token = IAlphaKeysToken(
            address(new AlphaKeysTokenProxy())
        );
        token.initialize(address(this), address(0), name, symbol);
        _twitterKeys[twitterId] = address(token);
        _keysTwitters[address(token)] = twitterId;
        //
        emit AlphaKeysCreatedForTwitter(address(0), address(token), twitterId);
    }

    function updateKeysPlayer(
        address token,
        address newPlayer
    ) external nonReentrant onlyAdmin {
        require(_playerKeys[newPlayer] == address(0), "AKF_PNZA");
        address oldPlayer = _keysPlayers[token];
        _playerKeys[oldPlayer] = address(0);
        //
        IAlphaKeysToken tokenIns = IAlphaKeysToken(token);
        tokenIns.updateNewPlayer(newPlayer);
        //
        _keysPlayers[token] = newPlayer;
        _playerKeys[newPlayer] = token;
    }

    // for migrate BTC

    function refundTC(uint256 amount) external nonReentrant onlyOwner {
        TransferHelper.safeTransferETH(owner(), amount);
    }

    function refundBTC(uint256 amount) external nonReentrant onlyOwner {
        address btc = _btc;
        TransferHelper.safeTransfer(btc, owner(), amount);
    }

    function requestFund(
        address token,
        address from,
        uint256 amount
    ) external onlyToken(_msgSender()) {
        if (amount > 0) {
            address vault = _vault;
            if (from == address(this)) {
                TransferHelper.safeTransfer(token, vault, amount);
            } else if (from != vault) {
                TransferHelper.safeTransferFrom(token, from, vault, amount);
            }
        }
    }

    function requestRefund(
        address token,
        address to,
        uint256 amount
    ) external onlyToken(_msgSender()) {
        if (amount > 0) {
            address vault = _vault;
            if (to != vault) {
                TransferHelper.safeTransferFrom(token, vault, to, amount);
            }
        }
    }

    // for buy keys

    function _buyKeysForV2ByToken(
        address token,
        address from,
        uint256 amountX18,
        uint256 buyPriceAfterFeeMax,
        address recipient,
        TokenTypes.OrderType orderType
    ) internal onlyToken(token) returns (uint256) {
        uint256 buyPriceAfterFee = IAlphaKeysToken(token).getBuyPriceAfterFeeV2(
            amountX18
        );
        require(buyPriceAfterFeeMax >= buyPriceAfterFee, "AKF_BBP");
        //
        IAlphaKeysToken(token).permitBuyKeysForV2(
            from,
            amountX18,
            recipient,
            orderType
        );
        return buyPriceAfterFee;
    }

    function _buyKeysForV2ByToken(
        address token,
        address from,
        uint256 amountX18,
        address recipient,
        TokenTypes.OrderType orderType
    ) internal onlyToken(token) {
        IAlphaKeysToken(token).permitBuyKeysForV2(
            from,
            amountX18,
            recipient,
            orderType
        );
    }

    function _sellKeysForV2ByToken(
        address token,
        address from,
        uint256 amountX18,
        uint256 sellPriceAfterFeeMin,
        address recipient,
        TokenTypes.OrderType orderType
    ) internal onlyToken(token) {
        require(
            sellPriceAfterFeeMin <=
                IAlphaKeysToken(token).getSellPriceAfterFeeV2(amountX18),
            "AKF_BSP"
        );
        IAlphaKeysToken(token).permitSellKeysForV2(
            from,
            amountX18,
            recipient,
            orderType
        );
    }

    function _sellKeysForV2ByToken(
        address token,
        address from,
        uint256 amountX18,
        address recipient,
        TokenTypes.OrderType orderType
    ) internal onlyToken(token) {
        IAlphaKeysToken(token).permitSellKeysForV2(
            from,
            amountX18,
            recipient,
            orderType
        );
    }

    function buyKeysForV2ByTwitterId(
        uint256 twitterId,
        uint256 amountX18,
        uint256 buyPriceAfterFeeMax,
        address recipient
    ) external notContract nonReentrant {
        address token = _twitterKeys[twitterId];
        _buyKeysForV2ByToken(
            token,
            _msgSender(),
            amountX18,
            buyPriceAfterFeeMax,
            recipient,
            TokenTypes.OrderType.SpotOrder
        );
    }

    function buyKeysV2ByToken(
        address token,
        uint256 amountX18,
        uint256 buyPriceAfterFeeMax
    ) external notContract nonReentrant {
        _buyKeysForV2ByToken(
            token,
            _msgSender(),
            amountX18,
            buyPriceAfterFeeMax,
            _msgSender(),
            TokenTypes.OrderType.SpotOrder
        );
    }

    function buyKeysForV2ByToken(
        address token,
        uint256 amountX18,
        uint256 buyPriceAfterFeeMax,
        address recipient
    ) external notContract nonReentrant {
        _buyKeysForV2ByToken(
            token,
            _msgSender(),
            amountX18,
            buyPriceAfterFeeMax,
            recipient,
            TokenTypes.OrderType.SpotOrder
        );
    }

    function sellKeysV2ByToken(
        address token,
        uint256 amountX18,
        uint256 sellPriceAfterFeeMin
    ) external notContract nonReentrant {
        _sellKeysForV2ByToken(
            token,
            _msgSender(),
            amountX18,
            sellPriceAfterFeeMin,
            _msgSender(),
            TokenTypes.OrderType.SpotOrder
        );
    }

    function sellKeysForV2ByToken(
        address token,
        uint256 amountX18,
        uint256 sellPriceAfterFeeMin,
        address recipient
    ) external notContract nonReentrant {
        _sellKeysForV2ByToken(
            token,
            _msgSender(),
            amountX18,
            sellPriceAfterFeeMin,
            recipient,
            TokenTypes.OrderType.SpotOrder
        );
    }

    // for gas station

    function getGasOrderMessageHash(
        uint256 nonce,
        address trader,
        uint256 amountBTC,
        uint256 rate,
        uint256 deadline
    ) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return
            keccak256(
                abi.encode(
                    address(this),
                    chainId,
                    nonce,
                    trader,
                    amountBTC,
                    rate,
                    deadline
                )
            );
    }

    function _verifyGasOrderTrader(
        uint256 nonce,
        address trader,
        uint256 amountBTC,
        uint256 rate,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (address, bytes32) {
        bytes32 messageHash = getGasOrderMessageHash(
            nonce,
            trader,
            amountBTC,
            rate,
            deadline
        );
        address signer = ECDSAUpgradeable.recover(
            ECDSAUpgradeable.toEthSignedMessageHash(messageHash),
            signature
        );
        // GP_NA: Signer Is Not ADmin
        require(signer == trader, "AKF_NT");
        return (signer, messageHash);
    }

    function requestTC(
        uint256 nonce,
        address trader,
        uint256 amountBTC,
        uint256 rate,
        uint256 deadline,
        bytes memory signature
    ) external notContract nonReentrant {
        require(amountBTC <= (0.00005 ether), "AKF_IA");
        require(!_usedNonces[trader][nonce], "AKF_BN");
        _usedNonces[trader][nonce] = true;
        //
        uint256 btcPrice = _btcPrice;
        require(rate == btcPrice && btcPrice > 0, "AKF_BR");
        //
        require(deadline >= _blockTimestamp(), "AKF_BD");
        //
        _verifyGasOrderTrader(
            nonce,
            trader,
            amountBTC,
            rate,
            deadline,
            signature
        );
        address btc = _btc;
        require(
            IERC20Upgradeable(btc).balanceOf(trader) >= amountBTC,
            "AKF_IBB"
        );
        //
        uint256 amountTC = amountBTC.mulPrice(btcPrice);
        //
        TransferHelper.safeTransferFrom(_btc, trader, address(this), amountBTC);
        TransferHelper.safeTransferETH(trader, amountTC);
        //
        emit TCRequested(trader, nonce, amountBTC, amountTC);
    }

    // for 3 3 order book

    function createThreeThreeOrderId(
        address tokenA,
        address tokenB,
        uint256 amount,
        uint256 buyPriceBAfterFeeMax
    ) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return
            keccak256(
                abi.encode(
                    address(this),
                    chainId,
                    tokenA,
                    tokenB,
                    amount,
                    buyPriceBAfterFeeMax,
                    _blockNumber()
                )
            );
    }

    function getThreeThreeOrder(
        bytes32 orderId
    ) public view returns (ThreeThreeTypes.Order memory order) {
        return _threeThreeOrders[orderId];
    }

    function threeThreeRequest(
        address tokenB,
        uint256 amount,
        uint256 buyPriceBAfterFeeMax
    )
        external
        notContract
        nonReentrant
        onlyPlayer(_msgSender())
        onlyToken(tokenB)
    {
        require(amount >= NumberMath.PRICE_UNIT, "AKF_ANV");
        //
        require(
            buyPriceBAfterFeeMax >=
                IAlphaKeysToken(tokenB).getBuyPriceAfterFeeV2(amount),
            "AKF_BBPM"
        );
        //
        address tokenA = _playerKeys[_msgSender()];
        require(tokenA != tokenB, "AKF_NET");
        //
        address ownerA = IAlphaKeysToken(tokenA).getPlayer();
        //
        require(_msgSender() == ownerA, "AKF_NOA");
        require(
            IERC20Upgradeable(_btc).balanceOf(ownerA) >= buyPriceBAfterFeeMax,
            "AKF_OANEB"
        );
        //
        bytes32 orderId = createThreeThreeOrderId(
            tokenA,
            tokenB,
            amount,
            buyPriceBAfterFeeMax
        );
        //
        require(_threeThreeOrders[orderId].tokenA == address(0), "AKF_BOI");
        //
        address ownerB = IAlphaKeysToken(tokenB).getPlayer();
        //
        _threeThreeOrders[orderId] = ThreeThreeTypes.Order({
            status: ThreeThreeTypes.OrderStatus.Unfilled,
            tokenA: tokenA,
            ownerA: ownerA,
            tokenB: tokenB,
            ownerB: ownerB,
            amount: amount,
            buyPriceBAfterFeeMax: buyPriceBAfterFeeMax,
            locked: true,
            amountA: 0,
            amountB: 0
        });
        //
        TransferHelper.safeTransferFrom(
            _btc,
            ownerA,
            _vault,
            buyPriceBAfterFeeMax
        );
        //
        emit ThreeThreeRequested(
            orderId,
            tokenA,
            ownerA,
            tokenB,
            ownerB,
            amount,
            buyPriceBAfterFeeMax
        );
    }

    function threeThreeTrade(
        bytes32 orderId,
        uint256 buyPriceAAfterFeeMax
    ) external notContract nonReentrant {
        require(buyPriceAAfterFeeMax > 0, "AKF_BPNZ");
        //
        ThreeThreeTypes.Order storage order = _threeThreeOrders[orderId];
        //
        require(
            order.status == ThreeThreeTypes.OrderStatus.Unfilled,
            "AKF_BOS"
        );
        require(order.locked, "AKF_ONL");
        //
        address tokenB = order.tokenB;
        address ownerB = IAlphaKeysToken(tokenB).getPlayer();
        //
        require(_msgSender() == ownerB, "AKF_NOB");
        // save ownerB
        order.ownerB = ownerB;
        order.status = ThreeThreeTypes.OrderStatus.Filled;
        //
        address ownerA = order.ownerA;
        address tokenA = order.tokenA;
        uint256 amount = order.amount;
        uint256 buyPriceBAfterFeeMax = order.buyPriceBAfterFeeMax;
        //
        address vault = _vault;
        //
        uint256 buyPriceAfterFee = _buyKeysForV2ByToken(
            tokenB,
            vault,
            amount,
            buyPriceBAfterFeeMax,
            ownerA,
            TokenTypes.OrderType.ThreeThreeOrder
        );
        uint256 refundAmount = buyPriceBAfterFeeMax.sub(buyPriceAfterFee);
        if (refundAmount > 0) {
            TransferHelper.safeTransferFrom(_btc, vault, ownerA, refundAmount);
        }
        //
        _buyKeysForV2ByToken(
            tokenA,
            ownerB,
            amount,
            buyPriceAfterFee,
            ownerB,
            TokenTypes.OrderType.ThreeThreeOrder
        );
        //
        emit ThreeThreeTrade(orderId, tokenA, ownerA, tokenB, ownerB, amount);
        //
        IAlphaKeysToken(tokenA).permitLock30D(ownerB, amount);
        IAlphaKeysToken(tokenB).permitLock30D(ownerA, amount);
    }

    function threeThreeRequestBTC(
        address tokenB,
        uint256 buyPriceBAfterFeeMax
    )
        external
        notContract
        nonReentrant
        onlyPlayer(_msgSender())
        onlyToken(tokenB)
    {
        require(buyPriceBAfterFeeMax > 0, "AKF_BPNZ");
        //
        address tokenA = _playerKeys[_msgSender()];
        require(tokenA != tokenB, "AKF_NET");
        //
        require(
            buyPriceBAfterFeeMax >=
                IAlphaKeysToken(tokenA).getBuyPriceAfterFeeV2(
                    NumberMath.PRICE_UNIT
                ) &&
                buyPriceBAfterFeeMax >=
                IAlphaKeysToken(tokenB).getBuyPriceAfterFeeV2(
                    NumberMath.PRICE_UNIT
                ),
            "AKF_BBPM"
        );
        //
        address ownerA = IAlphaKeysToken(tokenA).getPlayer();
        //
        require(_msgSender() == ownerA, "AKF_NOA");
        require(
            IERC20Upgradeable(_btc).balanceOf(ownerA) >= buyPriceBAfterFeeMax,
            "AKF_OANEB"
        );
        //
        bytes32 orderId = createThreeThreeOrderId(
            tokenA,
            tokenB,
            0,
            buyPriceBAfterFeeMax
        );
        //
        require(_threeThreeOrders[orderId].tokenA == address(0), "AKF_BOI");
        //
        address ownerB = IAlphaKeysToken(tokenB).getPlayer();
        //
        _threeThreeOrders[orderId] = ThreeThreeTypes.Order({
            status: ThreeThreeTypes.OrderStatus.Unfilled,
            tokenA: tokenA,
            ownerA: ownerA,
            tokenB: tokenB,
            ownerB: ownerB,
            amount: 0,
            buyPriceBAfterFeeMax: buyPriceBAfterFeeMax,
            locked: true,
            amountA: 0,
            amountB: 0
        });
        //
        TransferHelper.safeTransferFrom(
            _btc,
            ownerA,
            _vault,
            buyPriceBAfterFeeMax
        );
        //
        emit ThreeThreeRequested(
            orderId,
            tokenA,
            ownerA,
            tokenB,
            ownerB,
            0,
            buyPriceBAfterFeeMax
        );
    }

    function threeThreeTradeBTC(
        bytes32 orderId
    ) external notContract nonReentrant {
        ThreeThreeTypes.Order storage order = _threeThreeOrders[orderId];
        //
        require(
            order.status == ThreeThreeTypes.OrderStatus.Unfilled,
            "AKF_BOS"
        );
        require(order.locked, "AKF_ONL");
        require(order.amount == 0, "AKF_ONR");
        //
        address tokenB = order.tokenB;
        address ownerB = IAlphaKeysToken(tokenB).getPlayer();
        //
        require(_msgSender() == ownerB, "AKF_NOB");
        // save ownerB
        order.ownerB = ownerB;
        order.status = ThreeThreeTypes.OrderStatus.Filled;
        //
        address ownerA = order.ownerA;
        address tokenA = order.tokenA;
        uint256 buyPriceBAfterFeeMax = order.buyPriceBAfterFeeMax;
        uint24 protocolFeeRatioA = IAlphaKeysToken(tokenA)
            .getProtocolFeeRatio();
        uint24 playerFeeRatioA = IAlphaKeysToken(tokenA).getPlayerFeeRatio();
        uint256 amountA = NumberMath.getBuyAmountMaxWithCash(
            protocolFeeRatioA,
            playerFeeRatioA,
            tokenA,
            buyPriceBAfterFeeMax
        );
        uint24 protocolFeeRatioB = IAlphaKeysToken(tokenB)
            .getProtocolFeeRatio();
        uint24 playerFeeRatioB = IAlphaKeysToken(tokenB).getPlayerFeeRatio();
        uint256 amountB = NumberMath.getBuyAmountMaxWithCash(
            protocolFeeRatioB,
            playerFeeRatioB,
            tokenB,
            buyPriceBAfterFeeMax
        );
        order.amountA = amountA;
        order.amountB = amountB;
        // AKF_BANM: buy amount not min
        require(amountA > 0 && amountB > 0, "AKF_BANM");
        //
        address vault = _vault;
        //
        uint256 buyPriceAfterFee = _buyKeysForV2ByToken(
            tokenB,
            vault,
            amountB,
            buyPriceBAfterFeeMax,
            ownerA,
            TokenTypes.OrderType.ThreeThreeOrder
        );
        uint256 refundAmount = buyPriceBAfterFeeMax.sub(buyPriceAfterFee);
        if (refundAmount > 0) {
            TransferHelper.safeTransferFrom(_btc, vault, ownerA, refundAmount);
        }
        //
        _buyKeysForV2ByToken(
            tokenA,
            ownerB,
            amountA,
            buyPriceBAfterFeeMax,
            ownerB,
            TokenTypes.OrderType.ThreeThreeOrder
        );
        //
        emit ThreeThreeTradeBTC(
            orderId,
            tokenA,
            ownerA,
            tokenB,
            ownerB,
            amountA,
            amountB
        );
        //
        IAlphaKeysToken(tokenA).permitLock30D(ownerB, amountA);
        IAlphaKeysToken(tokenB).permitLock30D(ownerA, amountB);
    }

    function threeThreeCancel(
        bytes32 orderId
    ) external notContract nonReentrant {
        ThreeThreeTypes.Order storage order = _threeThreeOrders[orderId];
        //
        require(
            order.status == ThreeThreeTypes.OrderStatus.Unfilled,
            "AKF_BOS"
        );
        require(order.locked, "AKF_ONL");
        //
        address tokenA = order.tokenA;
        require(tokenA != address(0), "AKF_ITA");
        //
        address ownerA = IAlphaKeysToken(tokenA).getPlayer();
        require(_msgSender() == ownerA, "AKF_IOA");
        //
        order.status = ThreeThreeTypes.OrderStatus.Cancelled;
        //
        TransferHelper.safeTransferFrom(
            _btc,
            _vault,
            ownerA,
            order.buyPriceBAfterFeeMax
        );
        //
        emit ThreeThreeCancelled(orderId, tokenA, ownerA);
    }

    function threeThreeReject(
        bytes32 orderId
    ) external notContract nonReentrant {
        ThreeThreeTypes.Order storage order = _threeThreeOrders[orderId];
        //
        require(
            order.status == ThreeThreeTypes.OrderStatus.Unfilled,
            "AKF_BOS"
        );
        require(order.locked, "AKF_ONL");
        //
        address tokenB = order.tokenB;
        require(tokenB != address(0), "AKF_ITB");
        //
        address ownerB = IAlphaKeysToken(tokenB).getPlayer();
        require(_msgSender() == ownerB, "AKF_IOB");
        //
        address tokenA = order.tokenA;
        require(tokenA != address(0), "AKF_ITA");
        address ownerA = IAlphaKeysToken(tokenA).getPlayer();
        //
        order.status = ThreeThreeTypes.OrderStatus.Rejected;
        //
        TransferHelper.safeTransferFrom(
            _btc,
            _vault,
            ownerA,
            order.buyPriceBAfterFeeMax
        );
        //
        emit ThreeThreeRejected(orderId, tokenB, ownerB);
    }

    // for limit order

    function limitOrderCreate(
        uint256 nonce,
        address token,
        bool isBuy,
        uint256 amount,
        uint256 triggerPrice,
        uint256 buyPriceAfterFeeMax
    ) external notContract nonReentrant {
        address trader = _msgSender();
        LimitOrderTypes.Order storage order = _limitOrders[trader][nonce];
        require(order.trader == address(0), "AKF_BT");
        require(amount > 0 && buyPriceAfterFeeMax > 0, "AKF_BR");
        //
        order.trader = trader;
        order.token = token;
        order.isBuy = isBuy;
        order.amount = amount;
        order.triggerPrice = triggerPrice;
        order.buyPriceAfterFeeMax = buyPriceAfterFeeMax;
        order.status = LimitOrderTypes.OrderStatus.Unfilled;
        //
        TransferHelper.safeTransferFrom(
            _btc,
            trader,
            _vault,
            buyPriceAfterFeeMax
        );
        //
        emit LimitOrderCreated(
            nonce,
            trader,
            token,
            isBuy,
            amount,
            triggerPrice,
            buyPriceAfterFeeMax
        );
    }

    function limitOrderFill(
        uint256 nonce,
        address trader
    ) external notContract nonReentrant {
        LimitOrderTypes.Order storage order = _limitOrders[trader][nonce];
        require(order.trader == trader, "AKF_BT");
        require(
            order.status == LimitOrderTypes.OrderStatus.Unfilled,
            "AKF_BOS"
        );
        //
        _limitOrders[trader][nonce].status = LimitOrderTypes.OrderStatus.Filled;
        // fill order
        address token = order.token;
        uint256 triggerPrice = order.triggerPrice;
        uint256 amount = order.amount;
        bool isBuy = order.isBuy;
        uint256 buyPriceAfterFeeMax = order.buyPriceAfterFeeMax;
        //
        if (isBuy) {
            require(
                IAlphaKeysToken(token).getBuyPriceV2(NumberMath.ONE_ETHER) <=
                    triggerPrice,
                "AKF_BTBP"
            );
            // fill order
            address vault = _vault;
            uint256 buyPriceAfterFee = _buyKeysForV2ByToken(
                token,
                vault,
                amount,
                buyPriceAfterFeeMax,
                trader,
                TokenTypes.OrderType.LimitOrder
            );
            // refund
            uint256 refundAmount = buyPriceAfterFeeMax.sub(buyPriceAfterFee);
            if (refundAmount > 0) {
                address btc = _btc;
                TransferHelper.safeTransferFrom(
                    btc,
                    vault,
                    trader,
                    refundAmount
                );
            }
        } else {
            require(
                IAlphaKeysToken(token).getBuyPriceV2(NumberMath.ONE_ETHER) >=
                    triggerPrice,
                "AKF_BTSP"
            );
            _sellKeysForV2ByToken(
                token,
                trader,
                amount,
                trader,
                TokenTypes.OrderType.LimitOrder
            );
        }
        emit LimitOrderFilled(nonce, trader, token, isBuy, amount);
    }

    function limitOrderCancel(uint256 nonce) external notContract nonReentrant {
        address trader = _msgSender();
        LimitOrderTypes.Order storage order = _limitOrders[trader][nonce];
        require(order.trader == trader, "AKF_BT");
        require(
            order.status == LimitOrderTypes.OrderStatus.Unfilled,
            "AKF_BOS"
        );
        order.status = LimitOrderTypes.OrderStatus.Cancelled;
        //
        TransferHelper.safeTransferFrom(
            _btc,
            _vault,
            trader,
            order.buyPriceAfterFeeMax
        );
        //
        emit LimitOrderCancelled(nonce, trader);
    }

    // for watchlist

    function getWatchlistCopyTrade(
        uint256 twitterId,
        bytes32 orderId
    ) public view returns (bool) {
        return _copyTrades[twitterId][orderId];
    }

    function addWatchlist(
        uint256 watchTwitterId,
        uint256 amountMax,
        uint256 buyPriceMax
    )
        external
        notContract
        nonReentrant
        onlyPlayer(_msgSender())
        onlyTwitterId(watchTwitterId)
    {
        //
        require(
            amountMax <= (1024 ether) && buyPriceMax <= (10 ether),
            "AKF_BR"
        );
        //
        uint256 twitterId = getTwitterIdByPlayer(_msgSender());
        // same twitterId
        require(twitterId != watchTwitterId, "AKF_STI");
        // update watchlist
        WatchlistTypes.Watchlist storage watchlist = _watchlists[twitterId][
            watchTwitterId
        ];
        watchlist.enabled = true;
        watchlist.amountMax = amountMax;
        watchlist.buyPriceMax = buyPriceMax;
        watchlist.validAt = _blockTimestamp();
        //
        emit WatchlistUpdated(
            twitterId,
            watchTwitterId,
            true,
            amountMax,
            buyPriceMax,
            _blockTimestamp()
        );
    }

    function removeWatchlist(
        uint256 watchTwitterId
    )
        external
        notContract
        nonReentrant
        onlyPlayer(_msgSender())
        onlyTwitterId(watchTwitterId)
    {
        uint256 twitterId = getTwitterIdByPlayer(_msgSender());
        // update watchlist
        WatchlistTypes.Watchlist storage watchlist = _watchlists[twitterId][
            watchTwitterId
        ];
        watchlist.enabled = false;
        watchlist.amountMax = 0;
        watchlist.buyPriceMax = 0;
        //
        emit WatchlistUpdated(
            twitterId,
            watchTwitterId,
            false,
            0,
            0,
            _blockTimestamp()
        );
    }

    function buyWithWatchlist(
        uint256 twitterId,
        uint256 watchTwitterId,
        address token,
        bytes32 orderId
    )
        external
        notContract
        nonReentrant
        onlyTwitterId(twitterId)
        onlyTwitterId(watchTwitterId)
        onlyToken(token)
    {
        // copy trade existed
        require(_copyTrades[twitterId][orderId] == false, "AKF_CTE");
        _copyTrades[twitterId][orderId] = true;
        // update watchlist
        WatchlistTypes.Watchlist storage watchlist = _watchlists[twitterId][
            watchTwitterId
        ];
        uint256 amountMax = watchlist.amountMax;
        uint256 buyPriceMax = watchlist.buyPriceMax;
        // not configure watchlist
        require(
            watchlist.enabled && amountMax > 0 && buyPriceMax > 0,
            "AKF_NCW"
        );
        address watchTwitterTrader = getPlayerByTwitterId(watchTwitterId);
        //
        TokenTypes.TradeOrder memory watchOrder = IAlphaKeysToken(token)
            .getTradeOrder(orderId);
        // not match trade order
        require(
            watchOrder.trader == watchTwitterTrader &&
                watchOrder.isBuy == true &&
                watchOrder.orderType == TokenTypes.OrderType.SpotOrder &&
                watchOrder.createdAt > watchlist.validAt,
            "AKF_NMTO"
        );
        //
        address trader = getPlayerByTwitterId(twitterId);
        // estimate and copy trade
        uint24 protocolFeeRatioToken = IAlphaKeysToken(token)
            .getProtocolFeeRatio();
        uint24 palyerFeeRatioToken = IAlphaKeysToken(token).getPlayerFeeRatio();
        uint256 amountBuy = NumberMath.getBuyAmountMaxWithCondition(
            token,
            amountMax,
            buyPriceMax,
            NumberMath.getPaymentMaxFor(_btc, trader, address(this)).divRatio(
                uint24(NumberMath.RATIO) +
                    protocolFeeRatioToken +
                    palyerFeeRatioToken
            )
        );
        require(amountBuy > 0, "AKF_ABIZ");
        //
        _buyKeysForV2ByToken(
            token,
            trader,
            amountBuy,
            trader,
            TokenTypes.OrderType.WatchlistOrder
        );
        //
        emit WatchlistCopyTrade(
            twitterId,
            watchTwitterId,
            token,
            amountBuy,
            orderId
        );
    }
}
