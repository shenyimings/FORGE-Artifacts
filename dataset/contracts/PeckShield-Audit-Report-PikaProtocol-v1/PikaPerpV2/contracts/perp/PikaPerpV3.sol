// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '../oracle/IOracle.sol';
import '../lib/UniERC20.sol';
import '../lib/PerpLib.sol';
import './IPikaPerp.sol';
import './IFundingManager.sol';
import '../staking/IVaultReward.sol';

contract PikaPerpV3 is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;
    // All amounts are stored with 8 decimals

    // Structs

    struct Vault {
        // 32 bytes
        uint128 cap; // Maximum capacity. 16 bytes
        uint128 balance; // 16 bytes
        // 32 bytes
        uint96 staked; // Total staked by users. 12 bytes
        uint96 shares; // Total ownership shares. 12 bytes
        uint64 stakingPeriod; // Time required to lock stake (seconds). 8 bytes
    }

    struct Stake {
        // 32 bytes
        address owner; // 20 bytes
        uint96 amount; // 12 bytes
        // 32 bytes
        uint128 shares; // 16 bytes
        uint128 timestamp; // 16 bytes
    }

    struct Product {
        // 32 bytes
        address productToken;
        uint72 maxLeverage;
        uint16 fee; // In bps. 0.5% = 50.
        bool isActive;
        // 32 bytes
        uint64 openInterestLong;
        uint64 openInterestShort;
        uint32 minPriceChange; // 1.5%, the minimum oracle price up change for trader to close trade with profit
        uint32 weight; // share of the max exposure
        uint64 reserve; // Virtual reserve used to calculate slippage
    }

    struct Position {
        // 32 bytes
        uint64 productId;
        uint64 leverage;
        uint64 price;
        uint64 oraclePrice;
        // 32 bytes
        uint128 margin;
        int128 funding;
        // 32 bytes
        address owner;
        bool isLong;
        bool isNextPrice;
        uint80 timestamp;
    }

    // Variables

    address public owner;
    address public guardian;
    address public gov;
    address private token;
    address public oracle;
    address public protocolRewardDistributor;
    address public pikaRewardDistributor;
    address public vaultRewardDistributor;
    address public vaultTokenReward;
    address public feeCalculator;
    address public fundingManager;
    uint256 private tokenBase;
    uint256 public minMargin;
    uint256 public protocolRewardRatio = 2000;  // 20%
    uint256 public pikaRewardRatio = 3000;  // 30%
    uint256 public maxShift = 0.003e8; // max shift (shift is used adjust the price to balance the longs and shorts)
    uint256 public minProfitTime = 6 hours; // the time window where minProfit is effective
    uint256 public totalWeight; // total exposure weights of all product
    uint256 public exposureMultiplier = 10000; // exposure multiplier
    uint256 public utilizationMultiplier = 10000; // exposure multiplier
    uint256 public maxExposureMultiplier = 3; // total open interest of a product should not exceed maxExposureMultiplier * maxExposure
    uint256 private liquidationBounty = 5000; // In bps. 5000 = 50%
    uint256 public liquidationThreshold = 8000; // In bps. 8000 = 80%
    uint256 private pendingProtocolReward; // protocol reward collected
    uint256 private pendingPikaReward; // pika reward collected
    uint256 private pendingVaultReward; // vault reward collected
    uint256 public totalOpenInterest;
    uint256 public shiftDivider = 3;
    bool private canUserStake = true;
    bool private allowPublicLiquidator = false;
    bool private isTradeEnabled = true;
    bool private isManagerOnlyForOpen = false;
    bool private isManagerOnlyForClose = false;
    Vault private vault;
    uint256 private constant BASE = 10**8;

    mapping(uint256 => Product) private products;
    mapping(address => Stake) private stakes;
    mapping(uint256 => Position) private positions;
    mapping (address => bool) public liquidators;
    mapping (address => bool) public nextPriceManagers;
    mapping (address => bool) public managers;
    mapping (address => mapping (address => bool)) public approvedManagers;
    // Events

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 shares
    );
    event Redeemed(
        address indexed user,
        address indexed receiver,
        uint256 amount,
        uint256 shares,
        uint256 shareBalance,
        bool isFullRedeem
    );
    event NewPosition(
        uint256 indexed positionId,
        address indexed user,
        uint256 indexed productId,
        bool isLong,
        uint256 price,
        uint256 oraclePrice,
        uint256 margin,
        uint256 leverage,
        uint256 fee,
        bool isNextPrice,
        int256 funding
    );

    event AddMargin(
        uint256 indexed positionId,
        address indexed sender,
        address indexed user,
        uint256 margin,
        uint256 newMargin,
        uint256 newLeverage
    );
    event ClosePosition(
        uint256 indexed positionId,
        address indexed user,
        uint256 indexed productId,
        uint256 price,
        uint256 entryPrice,
        uint256 margin,
        uint256 leverage,
        uint256 fee,
        int256 pnl,
        int256 fundingPayment,
        bool wasLiquidated
    );
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 liquidatorReward,
        uint256 remainingReward
    );
    event ProtocolRewardDistributed(
        address to,
        uint256 amount
    );
    event PikaRewardDistributed(
        address to,
        uint256 amount
    );
    event VaultRewardDistributed(
        address to,
        uint256 amount
    );
    event VaultUpdated(
        Vault vault
    );
    event ProductAdded(
        uint256 productId,
        Product product
    );
    event ProductUpdated(
        uint256 productId,
        Product product
    );
    event AddressesSet(
        address oracle,
        address feeCalculator,
        address fundingManager
    );
    event OwnerUpdated(
        address newOwner
    );
    event GuardianUpdated(
        address newGuardian
    );
    event GovUpdated(
        address newGov
    );

    // Constructor

    constructor(address _token, uint256 _tokenBase, address _oracle, address _feeCalculator, address _fundingManager) {
        owner = msg.sender;
        guardian = msg.sender;
        gov = msg.sender;
        token = _token;
        tokenBase = _tokenBase;
        oracle = _oracle;
        feeCalculator = _feeCalculator;
        fundingManager = _fundingManager;
    }

    // Methods

    function stake(uint256 amount, address user) external payable nonReentrant {
        require((canUserStake || msg.sender == owner) && (msg.sender == user || _validateManager(user)), "!stake");
        IVaultReward(vaultRewardDistributor).updateReward(user);
        IVaultReward(vaultTokenReward).updateReward(user);
        IERC20(token).uniTransferFromSenderToThis(amount * tokenBase / BASE);
        require(uint256(vault.staked) + amount <= uint256(vault.cap), "!cap");
        uint256 shares = vault.staked > 0 ? amount * uint256(vault.shares) / uint256(vault.balance) : amount;
        vault.balance += uint128(amount);
        vault.staked += uint96(amount);
        vault.shares += uint96(shares);

        if (stakes[user].amount == 0) {
            stakes[user] = Stake({
            owner: user,
            amount: uint96(amount),
            shares: uint128(shares),
            timestamp: uint128(block.timestamp)
            });
        } else {
            stakes[user].amount += uint96(amount);
            stakes[user].shares += uint128(shares);
            if (!_validateManager(user)) {
                stakes[user].timestamp = uint128(block.timestamp);
            }
        }

        emit Staked(
            user,
            amount,
            shares
        );

    }

    function redeem(
        address user,
        uint256 shares,
        address receiver
    ) external {

        require(shares <= uint256(vault.shares) && (user == msg.sender || _validateManager(user)), "!redeem");

        IVaultReward(vaultRewardDistributor).updateReward(user);
        IVaultReward(vaultTokenReward).updateReward(user);
        Stake storage _stake = stakes[user];
        bool isFullRedeem = shares >= uint256(_stake.shares);
        if (isFullRedeem) {
            shares = uint256(_stake.shares);
        }

        uint256 timeDiff = block.timestamp - uint256(_stake.timestamp);
        require(timeDiff > uint256(vault.stakingPeriod), "!period");

        uint256 shareBalance = shares * uint256(vault.balance) / uint256(vault.shares);

        uint256 amount = shares * _stake.amount / uint256(_stake.shares);

        _stake.amount -= uint96(amount);
        _stake.shares -= uint128(shares);
        vault.staked -= uint96(amount);
        vault.shares -= uint96(shares);
        vault.balance -= uint128(shareBalance);

        require(totalOpenInterest <= uint256(vault.balance) * utilizationMultiplier / (10**4), "!utilized");

        if (isFullRedeem) {
            delete stakes[user];
        }
        IERC20(token).uniTransfer(receiver, shareBalance * tokenBase / BASE);

        emit Redeemed(
            user,
            receiver,
            amount,
            shares,
            shareBalance,
            isFullRedeem
        );
    }

    function openPosition(
        address user,
        uint256 productId,
        uint256 margin,
        bool isLong,
        uint256 leverage
    ) public payable nonReentrant {
        require(_validateManager(user) || (!isManagerOnlyForOpen && user == msg.sender), "!allowed");
        require(isTradeEnabled, "!enabled");
        // Check params
        require(margin >= minMargin && margin < type(uint64).max, "!margin");
        require(leverage >= 1 * BASE, "!lev");

        // Check product
        Product storage product = products[productId];
        require(product.isActive, "!active");
        require(leverage <= uint256(product.maxLeverage), "!max-lev");

        // Transfer margin plus fee
        uint256 tradeFee = PerpLib._getTradeFee(margin, leverage, uint256(product.fee), product.productToken, user, msg.sender, feeCalculator);
        IERC20(token).uniTransferFromSenderToThis((margin + tradeFee) * tokenBase / BASE);

        _updatePendingRewards(tradeFee);

        uint256 price = _calculatePrice(product.productToken, isLong, product.openInterestLong,
            product.openInterestShort, uint256(vault.balance) * uint256(product.weight) * exposureMultiplier / uint256(totalWeight) / (10**4),
            uint256(product.reserve), margin * leverage / BASE);

        _updateFundingAndOpenInterest(productId, margin * leverage / BASE, isLong, true);
        int256 funding = IFundingManager(fundingManager).getFunding(productId);

        Position storage position = positions[getPositionId(user, productId, isLong)];
        if (position.margin > 0) {
            price = (uint256(position.margin) * position.leverage * uint256(position.price) + margin * leverage * price) /
                (uint256(position.margin) * position.leverage + margin * leverage);
            funding = (int256(uint256(position.margin)) * int256(uint256(position.leverage)) * int256(position.funding) + int256(margin * leverage) * funding) /
                (int256(uint256(position.margin)) * int256(uint256(position.leverage)) + int256(margin * leverage));
            leverage = (uint256(position.margin) * uint256(position.leverage) + margin * leverage) / (uint256(position.margin) + margin);
            margin = uint256(position.margin) + margin;
        }

        positions[getPositionId(user, productId, isLong)] = Position({
        owner: user,
        productId: uint64(productId),
        margin: uint128(margin),
        leverage: uint64(leverage),
        price: uint64(price),
        oraclePrice: uint64(IOracle(oracle).getPrice(product.productToken)),
        timestamp: uint80(block.timestamp),
        isLong: isLong,
        // if no existing position, isNextPrice depends on if sender is a nextPriceManager,
        // else it is false if either existing position's isNextPrice is false or the current new position sender is not a nextPriceManager
        isNextPrice: position.margin == 0 ? nextPriceManagers[msg.sender] : (!position.isNextPrice ? false : nextPriceManagers[msg.sender]),
        funding: int128(funding)
        });
        emit NewPosition(
            getPositionId(user, productId, isLong),
            user,
            productId,
            isLong,
            price,
            IOracle(oracle).getPrice(product.productToken),
            margin,
            leverage,
            tradeFee,
            position.margin == 0 ? nextPriceManagers[msg.sender] : (!position.isNextPrice ? false : nextPriceManagers[msg.sender]),
            funding
        );
    }

    // Add margin to Position with positionId
    function addMargin(uint256 positionId, uint256 margin) external payable nonReentrant {

        IERC20(token).uniTransferFromSenderToThis(margin * tokenBase / BASE);

        // Check params
        require(margin >= minMargin, "!margin");

        // Check position
        Position storage position = positions[positionId];
        require(msg.sender == position.owner || _validateManager(position.owner), "!allowed");

        // New position params
        uint256 newMargin = uint256(position.margin) + margin;
        uint256 newLeverage = uint256(position.leverage) * uint256(position.margin) / newMargin;
        require(newLeverage >= 1 * BASE, "!low-lev");

        position.margin = uint128(newMargin);
        position.leverage = uint64(newLeverage);

        emit AddMargin(
            positionId,
            msg.sender,
            position.owner,
            margin,
            newMargin,
            newLeverage
        );

    }

    function closePosition(
        address user,
        uint256 productId,
        uint256 margin,
        bool isLong
    ) external {
        return closePositionWithId(getPositionId(user, productId, isLong), margin);
    }

    // Closes position from Position with id = positionId
    function closePositionWithId(
        uint256 positionId,
        uint256 margin
    ) public nonReentrant {
        // Check position
        Position storage position = positions[positionId];
        require(_validateManager(position.owner) || (!isManagerOnlyForClose && msg.sender == position.owner), "!close");

        // Check product
        Product storage product = products[uint256(position.productId)];

        bool isFullClose;
        if (margin >= uint256(position.margin)) {
            margin = uint256(position.margin);
            isFullClose = true;
        }

        uint256 price = _calculatePrice(product.productToken, !position.isLong, product.openInterestLong, product.openInterestShort,
            getMaxExposure(uint256(product.weight)), uint256(product.reserve), margin * position.leverage / BASE);

        _updateFundingAndOpenInterest(uint256(position.productId), margin * uint256(position.leverage) / BASE, position.isLong, false);
        int256 fundingPayment = PerpLib._getFundingPayment(fundingManager, position.isLong, position.productId, position.leverage, margin, position.funding);
        int256 pnl = PerpLib._getPnl(position.isLong, uint256(position.price), uint256(position.leverage), margin, price) - fundingPayment;
        bool isLiquidatable;
        if (pnl < 0 && uint256(-1 * pnl) >= margin * liquidationThreshold / (10**4)) {
            margin = uint256(position.margin);
            pnl = -1 * int256(uint256(position.margin));
            isLiquidatable = true;
        } else {
            // front running protection: if oracle price up change is smaller than threshold and minProfitTime has not passed
            // and either open or close order is not using next oracle price, the pnl is be set to 0
            if (pnl > 0 && !PerpLib._canTakeProfit(position.isLong, uint256(position.timestamp), uint256(position.oraclePrice),
                IOracle(oracle).getPrice(product.productToken), product.minPriceChange, minProfitTime) && (!position.isNextPrice || !nextPriceManagers[msg.sender])) {
                pnl = 0;
            }
        }

        uint256 totalFee = _updateVaultAndGetFee(pnl, position, margin, uint256(product.fee), product.productToken);

        emit ClosePosition(
            positionId,
            position.owner,
            uint256(position.productId),
            price,
            uint256(position.price),
            margin,
            uint256(position.leverage),
            totalFee,
            pnl,
            fundingPayment,
            isLiquidatable
        );

        if (isFullClose) {
            delete positions[positionId];
        } else {
            position.margin -= uint128(margin);
        }
    }

    function _updateVaultAndGetFee(
        int256 pnl,
        Position memory position,
        uint256 margin,
        uint256 fee,
        address productToken
    ) private returns(uint256) {
        uint256 totalFee = PerpLib._getTradeFee(margin, uint256(position.leverage), fee, productToken, position.owner, msg.sender, feeCalculator);
        int256 pnlAfterFee = pnl - int256(totalFee);
        // Update vault
        if (pnlAfterFee < 0) {
            uint256 _pnlAfterFee = uint256(-1 * pnlAfterFee);
            if (_pnlAfterFee < margin) {
                IERC20(token).uniTransfer(position.owner, (margin - _pnlAfterFee) * tokenBase / BASE);
                vault.balance += uint128(_pnlAfterFee);
            } else {
                vault.balance += uint128(margin);
                return totalFee;
            }

        } else {
            uint256 _pnlAfterFee = uint256(pnlAfterFee);
            // Check vault
            require(uint256(vault.balance) >= _pnlAfterFee, "!bal");
            vault.balance -= uint128(_pnlAfterFee);

            IERC20(token).uniTransfer(position.owner, (margin + _pnlAfterFee) * tokenBase / BASE);
        }

        _updatePendingRewards(totalFee);
        vault.balance -= uint128(totalFee);

        return totalFee;
    }

    // Liquidate positionIds
    function liquidatePositions(uint256[] calldata positionIds) external {
        require(liquidators[msg.sender] || allowPublicLiquidator, "!liquidator");

        uint256 totalLiquidatorReward;
        for (uint256 i = 0; i < positionIds.length; i++) {
            uint256 positionId = positionIds[i];
            uint256 liquidatorReward = liquidatePosition(positionId);
            totalLiquidatorReward = totalLiquidatorReward + liquidatorReward;
        }
        if (totalLiquidatorReward > 0) {
            IERC20(token).uniTransfer(msg.sender, totalLiquidatorReward * tokenBase / BASE);
        }
    }


    function liquidatePosition(
        uint256 positionId
    ) private returns(uint256 liquidatorReward) {
        Position storage position = positions[positionId];
        if (position.productId == 0) {
            return 0;
        }
        Product storage product = products[uint256(position.productId)];
        uint256 price = IOracle(oracle).getPrice(product.productToken); // use oracle price for liquidation

        uint256 remainingReward;
        _updateFundingAndOpenInterest(uint256(position.productId), uint256(position.margin) * uint256(position.leverage) / BASE, position.isLong, false);
        int256 fundingPayment = PerpLib._getFundingPayment(fundingManager, position.isLong, position.productId, position.leverage, position.margin, position.funding);
        int256 pnl = PerpLib._getPnl(position.isLong, position.price, position.leverage, position.margin, price) - fundingPayment;
        if (pnl >= 0 || uint256(-1 * pnl) < uint256(position.margin) * liquidationThreshold / (10**4)) {
            return 0;
        }
        if (uint256(position.margin) > uint256(-1*pnl)) {
            uint256 _pnl = uint256(-1*pnl);
            liquidatorReward = (uint256(position.margin) - _pnl) * liquidationBounty / (10**4);
            remainingReward = uint256(position.margin) - _pnl - liquidatorReward;
            _updatePendingRewards(remainingReward);
            vault.balance += uint128(_pnl);
        } else {
            vault.balance += uint128(position.margin);
        }

        emit ClosePosition(
            positionId,
            position.owner,
            uint256(position.productId),
            price,
            uint256(position.price),
            uint256(position.margin),
            uint256(position.leverage),
            0,
            -1*int256(uint256(position.margin)),
            fundingPayment,
            true
        );

        delete positions[positionId];

        emit PositionLiquidated(
            positionId,
            msg.sender,
            liquidatorReward,
            remainingReward
        );

        return liquidatorReward;
    }

    function _updatePendingRewards(uint256 reward) private {
        pendingProtocolReward = pendingProtocolReward + (reward * protocolRewardRatio / (10**4));
        pendingPikaReward = pendingPikaReward + (reward * pikaRewardRatio / (10**4));
        pendingVaultReward = pendingVaultReward + (reward * (10**4 - protocolRewardRatio - pikaRewardRatio) / (10**4));
    }

    function _updateFundingAndOpenInterest(uint256 productId, uint256 amount, bool isLong, bool isIncrease) private {
        IFundingManager(fundingManager).updateFunding(productId);
        Product storage product = products[productId];
        if (isIncrease) {
            totalOpenInterest = totalOpenInterest + amount;
            uint256 maxExposure = getMaxExposure(uint256(product.weight));
            require(totalOpenInterest <= uint256(vault.balance) * utilizationMultiplier / 10**4 &&
                uint256(product.openInterestLong) + uint256(product.openInterestShort) + amount < maxExposureMultiplier * maxExposure, "!maxOI");
            if (isLong) {
                product.openInterestLong = product.openInterestLong + uint64(amount);
                require(uint256(product.openInterestLong) <= uint256(maxExposure) + uint256(product.openInterestShort), "!exposure-long");
            } else {
                product.openInterestShort = product.openInterestShort + uint64(amount);
                require(uint256(product.openInterestShort) <= uint256(maxExposure) + uint256(product.openInterestLong), "!exposure-short");
            }
        } else {
            totalOpenInterest = totalOpenInterest - amount;
            if (isLong) {
                if (uint256(product.openInterestLong) >= amount) {
                    product.openInterestLong -= uint64(amount);
                } else {
                    product.openInterestLong = 0;
                }
            } else {
                if (uint256(product.openInterestShort) >= amount) {
                    product.openInterestShort -= uint64(amount);
                } else {
                    product.openInterestShort = 0;
                }
            }
        }
    }

    function _validateManager(address account) private view returns(bool) {
        return managers[msg.sender] && approvedManagers[account][msg.sender];
    }

    function distributeProtocolReward() external returns(uint256) {
        require(msg.sender == protocolRewardDistributor, "!dist");
        uint256 _pendingProtocolReward = pendingProtocolReward * tokenBase / BASE;
        if (pendingProtocolReward > 0) {
            pendingProtocolReward = 0;
            IERC20(token).uniTransfer(protocolRewardDistributor, _pendingProtocolReward);
            emit ProtocolRewardDistributed(protocolRewardDistributor, _pendingProtocolReward);
        }
        return _pendingProtocolReward;
    }

    function distributePikaReward() external returns(uint256) {
        require(msg.sender == pikaRewardDistributor, "!dist");
        uint256 _pendingPikaReward = pendingPikaReward * tokenBase / BASE;
        if (pendingPikaReward > 0) {
            pendingPikaReward = 0;
            IERC20(token).uniTransfer(pikaRewardDistributor, _pendingPikaReward);
            emit PikaRewardDistributed(pikaRewardDistributor, _pendingPikaReward);
        }
        return _pendingPikaReward;
    }

    function distributeVaultReward() external returns(uint256) {
        require(msg.sender == vaultRewardDistributor, "!dist");
        uint256 _pendingVaultReward = pendingVaultReward * tokenBase / BASE;
        if (pendingVaultReward > 0) {
            pendingVaultReward = 0;
            IERC20(token).uniTransfer(vaultRewardDistributor, _pendingVaultReward);
            emit VaultRewardDistributed(vaultRewardDistributor, _pendingVaultReward);
        }
        return _pendingVaultReward;
    }

    // Getters

    function getPendingPikaReward() external view returns(uint256) {
        return pendingPikaReward * tokenBase / BASE;
    }

    function getPendingProtocolReward() external view returns(uint256) {
        return pendingProtocolReward * tokenBase / BASE;
    }

    function getPendingVaultReward() external view returns(uint256) {
        return pendingVaultReward * tokenBase / BASE;
    }

    function getVault() external view returns(Vault memory) {
        return vault;
    }

    function getProduct(uint256 productId) external view returns (
        address,uint256,uint256,bool,uint256,uint256,uint256,uint256,uint256
    ) {
        Product memory product = products[productId];
        return (
        product.productToken,
        uint256(product.maxLeverage),
        uint256(product.fee),
        product.isActive,
        uint256(product.openInterestLong),
        uint256(product.openInterestShort),
        uint256(product.minPriceChange),
        uint256(product.weight),
        uint256(product.reserve));
    }

    function getPositionId(
        address account,
        uint256 productId,
        bool isLong
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account, productId, isLong)));
    }

    function getPosition(
        address account,
        uint256 productId,
        bool isLong
    ) external view returns (
        uint256,uint256,uint256,uint256,uint256,address,uint256,bool,int256
    ) {
        Position memory position = positions[getPositionId(account, productId, isLong)];
        return(
        uint256(position.productId),
        uint256(position.leverage),
        uint256(position.price),
        uint256(position.oraclePrice),
        uint256(position.margin),
        position.owner,
        uint256(position.timestamp),
        position.isLong,
        position.funding);
    }

    function getPositions(uint256[] calldata positionIds) external view returns(Position[] memory _positions) {
        uint256 length = positionIds.length;
        _positions = new Position[](length);
        for (uint256 i = 0; i < length; i++) {
            _positions[i] = positions[positionIds[i]];
        }
    }

    function getMaxExposure(uint256 productWeight) public view returns(uint256) {
        return uint256(vault.balance) * productWeight * exposureMultiplier / uint256(totalWeight) / (10**4);
    }

    function getTotalShare() external view returns(uint256) {
        return uint256(vault.shares);
    }

    function getShare(address stakeOwner) external view returns(uint256) {
        return uint256(stakes[stakeOwner].shares);
    }

    function getStake(address stakeOwner) external view returns(Stake memory) {
        return stakes[stakeOwner];
    }

    // Private methods

    function _calculatePrice(
        address productToken,
        bool isLong,
        uint256 openInterestLong,
        uint256 openInterestShort,
        uint256 maxExposure,
        uint256 reserve,
        uint256 amount
    ) private view returns(uint256) {
        uint256 oraclePrice = isLong ? IOracle(oracle).getPrice(productToken, true) : IOracle(oracle).getPrice(productToken, false);
        int256 shift = (int256(openInterestLong) - int256(openInterestShort)) * int256(maxShift) / int256(maxExposure);
        if (isLong) {
            uint256 slippage = (reserve * reserve / (reserve - amount) - reserve) * BASE / amount;
            slippage = shift >= 0 ? slippage + uint256(shift) : slippage - (uint256(-1 * shift) / shiftDivider);
            return oraclePrice * slippage / BASE;
        } else {
            uint256 slippage = (reserve - (reserve * reserve) / (reserve + amount)) * BASE / amount;
            slippage = shift >= 0 ? slippage + (uint256(shift) / shiftDivider) : slippage - uint256(-1 * shift);
            return oraclePrice * slippage / BASE;
        }
    }

    // Owner methods

    function updateVault(Vault memory _vault) external {
        onlyOwner();
        require(_vault.cap > 0 && _vault.stakingPeriod > 0 && _vault.stakingPeriod < 30 days, "!allowed");

        vault.cap = _vault.cap;
        vault.stakingPeriod = _vault.stakingPeriod;

        emit VaultUpdated(vault);
    }

    function addProduct(uint256 productId, Product memory _product) external {
        onlyOwner();
        require(productId > 0);
        Product memory product = products[productId];

        require(product.maxLeverage == 0 && _product.maxLeverage > 1 * BASE && _product.productToken != address(0));

        products[productId] = Product({
        productToken: _product.productToken,
        maxLeverage: _product.maxLeverage,
        fee: _product.fee,
        isActive: true,
        openInterestLong: 0,
        openInterestShort: 0,
        minPriceChange: _product.minPriceChange,
        weight: _product.weight,
        reserve: _product.reserve
        });
        totalWeight = totalWeight + _product.weight;

        emit ProductAdded(productId, products[productId]);
    }

    function updateProduct(uint256 productId, Product memory _product) external {
        onlyOwner();
        require(productId > 0);
        Product storage product = products[productId];

        require(product.maxLeverage > 0 && _product.maxLeverage >= 1 * BASE && _product.productToken != address(0));

        product.productToken = _product.productToken;
        product.maxLeverage = _product.maxLeverage;
        product.fee = _product.fee;
        product.isActive = _product.isActive;
        product.minPriceChange = _product.minPriceChange;
        totalWeight = totalWeight - product.weight + _product.weight;
        product.weight = _product.weight;
        product.reserve = _product.reserve;

        emit ProductUpdated(productId, product);

    }

    function setDistributors(
        address _protocolRewardDistributor,
        address _pikaRewardDistributor,
        address _vaultRewardDistributor,
        address _vaultTokenReward
    ) external {
        onlyOwner();
        protocolRewardDistributor = _protocolRewardDistributor;
        pikaRewardDistributor = _pikaRewardDistributor;
        vaultRewardDistributor = _vaultRewardDistributor;
        vaultTokenReward = _vaultTokenReward;
    }

    function setManager(address _manager, bool _isActive) external {
        onlyOwner();
        managers[_manager] = _isActive;
    }

    function setAccountManager(address _manager, bool _isActive) external {
        approvedManagers[msg.sender][_manager] = _isActive;
    }

    function setRewardRatio(uint256 _protocolRewardRatio, uint256 _pikaRewardRatio) external {
        onlyOwner();
        require(_protocolRewardRatio + _pikaRewardRatio <= 10000);
        protocolRewardRatio = _protocolRewardRatio;
        pikaRewardRatio = _pikaRewardRatio;
    }

    function setMinMargin(uint256 _minMargin) external {
        onlyOwner();
        minMargin = _minMargin;
    }

    function setTradeEnabled(bool _isTradeEnabled) external {
        require(msg.sender == owner || managers[msg.sender]);
        isTradeEnabled = _isTradeEnabled;
    }

    function setParameters(
        uint256 _maxShift,
        uint256 _minProfitTime,
        bool _canUserStake,
        bool _allowPublicLiquidator,
        bool _isManagerOnlyForOpen,
        bool _isManagerOnlyForClose,
        uint256 _exposureMultiplier,
        uint256 _utilizationMultiplier,
        uint256 _maxExposureMultiplier,
        uint256 _liquidationBounty,
        uint256 _liquidationThreshold,
        uint256 _shiftDivider
    ) external {
        onlyOwner();
        require(_maxShift <= 0.01e8 && _minProfitTime <= 24 hours && _shiftDivider > 0 && _liquidationThreshold > 5000 && _maxExposureMultiplier > 0);
        maxShift = _maxShift;
        minProfitTime = _minProfitTime;
        canUserStake = _canUserStake;
        allowPublicLiquidator = _allowPublicLiquidator;
        isManagerOnlyForOpen = _isManagerOnlyForOpen;
        isManagerOnlyForClose = _isManagerOnlyForClose;
        exposureMultiplier = _exposureMultiplier;
        utilizationMultiplier = _utilizationMultiplier;
        maxExposureMultiplier = _maxExposureMultiplier;
        liquidationBounty = _liquidationBounty;
        liquidationThreshold = _liquidationThreshold;
        shiftDivider = _shiftDivider;
    }

    function setAddresses(address _oracle, address _feeCalculator, address _fundingManager) external {
        onlyOwner();
        oracle = _oracle;
        feeCalculator = _feeCalculator;
        fundingManager = _fundingManager;
        emit AddressesSet(_oracle, _feeCalculator, _fundingManager);
    }

    function setLiquidator(address _liquidator, bool _isActive) external {
        onlyOwner();
        liquidators[_liquidator] = _isActive;
    }

    function setNextPriceManager(address _nextPriceManager, bool _isActive) external {
        onlyOwner();
        nextPriceManagers[_nextPriceManager] = _isActive;
    }

    function setOwner(address _owner) external {
        onlyGov();
        owner = _owner;
        emit OwnerUpdated(_owner);
    }

    function setGuardian(address _guardian) external {
        onlyGov();
        guardian = _guardian;
        emit GuardianUpdated(_guardian);
    }

    function setGov(address _gov) external {
        onlyGov();
        gov = _gov;
        emit GovUpdated(_gov);
    }

    function pauseTrading() external {
        require(msg.sender == guardian, "!guard");
        isTradeEnabled = false;
        canUserStake = false;
    }

    function onlyOwner() private {
        require(msg.sender == owner, "!owner");
    }

    function onlyGov() private {
        require(msg.sender == gov, "!gov");
    }

}
