pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

// Deployment process:
// deploy 2 proxies
// deploy Dex, Oracle and TokenReserve
// initConfigure Dex and TokenReserve
// migrate data 
// remove all migration role members
// contract is trading

import "./HOracle.sol";
import "./libraries/FIFOSet.sol";
import "./libraries/Proportional.sol";
import "./token/HTokenReserve.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

interface IHTokenReserve {
    function erc20Contract() external view returns(address erc20);
    function issueHTEthUsd(address user, uint amountUsd) external returns(uint amtHcEthUsd);
    function burnHTEthUsd(address user, uint amountUsd) external returns(uint amtHcEthUsd);
    function tokenReserveContract() external view returns(IHTokenReserve _reserve);
    function dexContract() external view returns(address dexAddr);
}

contract HodlDexV0 is IDex, Initializable, AccessControl {
    
    using SafeMath for uint;                                        // OpenZeppelin safeMath utility
    using FIFOSet for FIFOSet.Set;                                  // FIFO key sets
    using Proportional for Proportional.System;                     // Balance management with proportional distribution 
    
    IHOracle oracle;                                                // Must implement the read() view function (EthUsd18 uint256)
    IHTokenReserve tokenReserve;                                    // The ERC20 token reserve
    
    bytes32 constant public MIGRATION_ROLE = keccak256("Migration Role");
    bytes32 constant public RESERVE_ROLE = keccak256("Reserve Role");
    bytes32 constant public ORACLE_ROLE = keccak256("Oracle Role");
    bytes32 constant public ADMIN_ROLE = keccak256("Admin Role");  
    bytes32 constant public ETH_ASSET = keccak256("Eth");
    bytes32 constant public HODL_ASSET = keccak256("HODL");
    
    bytes32[] assetIds;                                             // Accessible in the library

    bytes32 constant NULL = bytes32(0); 
    address constant UNDEFINED = address(0);
    uint constant PRECISION = 10 ** 18;                             // Precision is 18 decimal places
    uint constant TOTAL_SUPPLY = 20000000 * (10**18);               // Total supply - initially goes to the reserve, which is address(this)
    uint constant SLEEP_TIME = 30 days;                             // Grace period before time-based accrual kicks in
    uint constant DAILY_ACCRUAL_RATE_DECAY = 999999838576236000;    // Rate of decay applied daily reduces daily accrual APR to about 5% after 30 years
    uint constant USD_TXN_ADJUSTMENT = 10**14;                      // $0.0001 with 18 decimal places of precision - 1/100th of a cent
    
    uint constant BIRTHDAY = 1595899309;                            // Now time when the contract was deployed
    uint constant MIN_ORDER_USD = 50 * 10 ** 18;                    // Minimum order size is $50 in USD precision
    uint constant MAX_THRESHOLD_USD = 10 * 10 ** 18;                // Order limits removed when HODL_USD exceeds $10
    uint constant MAX_ORDER_FACTOR = 5000;                          // Max Order Volume will be 5K * hodl_usd until threshold ($10).  
    uint constant DISTRIBUTION_PERIOD = 30 days;                    // Periodicity for distributions

    /**************************************************************************************
     * block 11094768 values from old dex at 0x56b9d34F9f4E4A1A82D847128c1B2264B34D2fAe
    **************************************************************************************/    

    uint constant _accrualDaysProcessed = 54;                       // Days of stateful accrual applied
    uint constant _HODL_USD = 1335574612014710427;                  // HODL:USD exchange rate last recorded
    uint constant _DAILY_ACCRUAL_RATE = 1001892104261953098;        // Initial daily accrual is 0.19% (100.19% multiplier) which is about 100% APR
    uint public accrualDaysProcessed;
    uint private HODL_USD;
    uint private DAILY_ACCRUAL_RATE;

    /**************************************************************************************
     * Counters
     **************************************************************************************/     
    
    uint public entropy_counter;                                    // Ensure unique order ids
    uint public eth_usd_block;                                      // Block number of last ETH_USD recorded
    uint public error_count;                                        // Oracle read errors
    uint public ETH_USD;                                            // Last recorded ETH_USD rate

    Proportional.System balance;                                    // Account balances with proportional distribution system 

    struct SellOrder {
        address seller;
        uint volumeHodl;
        uint askUsd;
    } 
    
    struct BuyOrder {
        address buyer;
        uint bidEth;
    }
    
    mapping(bytes32 => SellOrder) public sellOrder;
    mapping(bytes32 => BuyOrder) public buyOrder; 

    FIFOSet.Set sellOrderIdFifo;                                    // SELL orders in order of declaration
    FIFOSet.Set buyOrderIdFifo;                                     // BUY orders in order of declaration
    
    modifier onlyAdmin {
        require(hasRole(ADMIN_ROLE, msg.sender), "HodlDex 403 admin");
        _;
    }
    
    modifier onlyOracle {
        require(hasRole(ORACLE_ROLE, msg.sender), "HodlDex 403 oracle");
        _;
    }
    
    modifier onlyMigration {
        require(hasRole(MIGRATION_ROLE, msg.sender), "HodlDex 403 migration");
        _;
    }
    
    modifier onlyReserve {
        require(hasRole(RESERVE_ROLE, msg.sender), "HodlDex 403 reserve.");
        _; 
    }
    
    modifier ifRunning {
        require(isRunning(), "HodleDex uninitialized.");
        _;
    }

    modifier accrueByTime {
        _;
        _accrueByTime();
    }

    event HodlTIssued(address indexed user, uint amountUsd, uint amountHodl);
    event HodlTRedeemed(address indexed user, uint amountUsd, uint amountHodl);
    event SellHodlCRequested(address indexed seller, uint quantityHodl, uint lowGas);
    event SellOrderFilled(address indexed buyer, bytes32 indexed orderId, address indexed seller, uint txnEth, uint txnHodl);
    event SellOrderRefunded(address indexed seller, bytes32 indexed orderId, uint refundedHodl);    
    event SellOrderOpened(bytes32 indexed orderId, address indexed seller, uint quantityHodl, uint askUsd);
    event BuyHodlCRequested(address indexed buyer, uint amountEth, uint lowGas);
    event BuyOrderFilled(address indexed seller, bytes32 indexed orderId, address indexed buyer, uint txnEth, uint txnHodl);
    event BuyOrderRefunded(address indexed seller, bytes32 indexed orderId, uint refundedEth);
    event BuyFromReserve(address indexed buyer, uint txnEth, uint txnHodl);
    event BuyOrderOpened(bytes32 indexed orderedId, address indexed buyer, uint amountEth);
    event SellOrderCancelled(address indexed userAddr, bytes32 indexed orderId);
    event BuyOrderCancelled(address indexed userAddr, bytes32 indexed orderId);
    event UserDepositEth(address indexed user, uint amountEth);
    event UserWithdrawEth(address indexed user, uint amountEth);
    event InitConfigure(address sender, IHTokenReserve tokenReserve, IHOracle oracle);
    event UserInitialized(address admin, address indexed user, uint hodlCR, uint ethCR);
    event UserUninitialized(address admin, address indexed user);
    event OracleSet(address admin, address oracle);
    event SetEthUsd(address setter, uint ethUsd18);
    event SetDailyAccrualRate(address admin, uint dailyAccrualRate);
    event EthUsdError(address sender, uint errorCount, uint ethUsd);
    event IncreaseGas(address sender, uint gasLeft, uint ordersFilled);
    event IncreasedByTransaction(address sender, uint transactionCount, uint newHodlUsd);
    event AccrueByTime(address sender, uint hodlUsdNow, uint dailyAccrualRateNow);
    event InternalTransfer(address sender, address from, address to, uint amount);
    event HodlDistributionAllocated(address sender, uint amount);

    /**************************************************************************************
     * @dev run init() before using this contract
     **************************************************************************************/ 

    function keyGen() private returns(bytes32 key) {
        entropy_counter++;
        return keccak256(abi.encodePacked(address(this), msg.sender, entropy_counter));
    }
    
    function oracleContract() external view returns(IHOracle _oracle) {
        return oracle;
    }
    
    function tokenReserveContract() external view returns(IHTokenReserve _reserve) {
        return tokenReserve;
    }

    /**************************************************************************************
     * An admin may change the oracle service
     **************************************************************************************/    
    
    function adminSetOracle(IHOracle _oracle) external onlyAdmin {
        oracle = _oracle;
        emit OracleSet(msg.sender, address(_oracle));
    }

    /**************************************************************************************
     * An Oracle may inject a new Eth:Usd rate
     **************************************************************************************/ 
    
    function oracleSetEthUsd(uint ethUsd) external onlyOracle {
        ETH_USD = ethUsd;
        eth_usd_block = block.number;
        emit SetEthUsd(msg.sender, ethUsd);
    }    

    /**************************************************************************************
     * Anyone can nudge the time-based accrual and distribution accounting periods forward
     **************************************************************************************/ 

    function poke() public ifRunning {
        _accrueByTime();
        _setEthToUsd();
    }

    /**************************************************************************************
     * Convertability to HODLT USD TOKEN ERC20
     **************************************************************************************/    
    
    function hodlTIssue(uint amountUsd) external accrueByTime ifRunning {
        uint amountHodl = tokenReserve.issueHTEthUsd(msg.sender, amountUsd);
        emit HodlTIssued(msg.sender, amountUsd, amountHodl);
        balance.sub(HODL_ASSET, msg.sender, amountHodl, 0);
        balance.add(HODL_ASSET, address(tokenReserve), amountHodl, 0);
    }

    function hodlTRedeem(uint amountUsd) external accrueByTime ifRunning {
        uint amountHodl = tokenReserve.burnHTEthUsd(msg.sender, amountUsd);
        emit HodlTRedeemed(msg.sender, amountUsd, amountHodl);
        balance.add(HODL_ASSET, msg.sender, amountHodl, 0);
        balance.sub(HODL_ASSET, address(tokenReserve), amountHodl, 0);
    }

    function allocateDistribution(uint amountHodl) external override ifRunning onlyReserve {
        emit HodlDistributionAllocated(msg.sender, amountHodl);
        balance.sub(HODL_ASSET, address(tokenReserve), amountHodl, 0);
        balance.increaseDistribution(HODL_ASSET, amountHodl);
    }
    
    /**************************************************************************************
     * Claim distributions
     **************************************************************************************/      
    
    function claimEthDistribution() external ifRunning returns(uint amountEth) {
        amountEth = balance.processNextUserDistribution(ETH_ASSET, msg.sender);
    }
    
    function claimHodlDistribution() external ifRunning returns(uint amountHodl) {
        amountHodl = balance.processNextUserDistribution(HODL_ASSET, msg.sender);
    }

    /**************************************************************************************
     * Sell HodlC to buy orders, or if no buy orders open a sell order.
     * Selectable low gas protects against future EVM price changes.
     * Completes as much as possible (gas) and return unprocessed Hodl.
     **************************************************************************************/ 

    function sellHodlC(uint quantityHodl, uint lowGas) external accrueByTime ifRunning returns(bytes32 orderId) {
        emit SellHodlCRequested(msg.sender, quantityHodl, lowGas);
        uint orderUsd = convertHodlToUsd(quantityHodl); 
        uint orderLimit = orderLimit();
        require(orderUsd >= MIN_ORDER_USD, "HodlDex, < min USD");
        require(orderUsd <= orderLimit || orderLimit == 0, "HodlDex, > max USD");
        quantityHodl = _fillBuyOrders(quantityHodl, lowGas);
        orderId = _openSellOrder(quantityHodl);
    }

    function _fillBuyOrders(uint quantityHodl, uint lowGas) private returns(uint remainingHodl) {
        bytes32 orderId;
        address orderBuyer;
        uint orderHodl;
        uint orderEth;
        uint txnEth;
        uint txnHodl;
        uint ordersFilled;

        while(buyOrderIdFifo.count() > 0 && quantityHodl > 0) { 
            if(gasleft() < lowGas) {
                emit IncreaseGas(msg.sender, gasleft(), ordersFilled);
                return 0;
            }
            orderId = buyOrderIdFifo.first();
            BuyOrder storage o = buyOrder[orderId]; 
            orderBuyer = o.buyer;
            orderEth = o.bidEth;
            orderHodl = _convertEthToHodl(orderEth);
            
            if(orderHodl == 0) {
                // First order is now too small to fill. Refund eth and prune the order.
                if(orderEth > 0) {
                    balance.add(ETH_ASSET, orderBuyer, orderEth, 0);
                    emit BuyOrderRefunded(msg.sender, orderId, orderEth); 
                }
                delete buyOrder[orderId];
                buyOrderIdFifo.remove(orderId);
            } else {
                // Seller wants to sell hodl with Eth value
                txnEth  = _convertHodlToEth(quantityHodl);
                txnHodl = quantityHodl;
                // Fill some or all of the open order
                if(orderEth < txnEth) {
                    txnEth = orderEth;
                    txnHodl = orderHodl;
                }
                emit BuyOrderFilled(msg.sender, orderId, orderBuyer, txnEth, txnHodl);
                // Transfer hodl from seller to buyer 
                balance.sub(HODL_ASSET, msg.sender, txnHodl, 0);
                balance.add(HODL_ASSET, orderBuyer, txnHodl, 0);
                // Award Eth to seller 
                balance.add(ETH_ASSET, msg.sender, txnEth, 0);
                if(orderEth == txnEth) {
                    // delete filled order 
                    delete buyOrder[orderId];
                    buyOrderIdFifo.remove(orderId);
                // the the order is partially filled, then deduct Eth from the order
                } else {
                    // deduct eth from a partially filled order
                    o.bidEth = orderEth.sub(txnEth, "HodlDex 500");
                    quantityHodl = quantityHodl.sub(txnHodl, "HodlDex 501");  
                }
                ordersFilled++;
                _increaseTransactionCount(1);
            }          
        }
        remainingHodl = quantityHodl;
    }

    function _openSellOrder(uint quantityHodl) private returns(bytes32 orderId) {
        // Do not allow low gas to result in small sell orders or sell orders to exist while buy orders exist
        if(convertHodlToUsd(quantityHodl) > MIN_ORDER_USD && buyOrderIdFifo.count() == 0) { 
            orderId = keyGen();
            (uint askUsd, /* uint accrualRate */) = rates();
            SellOrder storage o = sellOrder[orderId];
            sellOrderIdFifo.append(orderId);
            emit SellOrderOpened(orderId, msg.sender, quantityHodl, askUsd);
            balance.add(HODL_ASSET, msg.sender, 0, quantityHodl);
            o.seller = msg.sender;
            o.volumeHodl = quantityHodl;
            o.askUsd = askUsd;
            balance.sub(HODL_ASSET, msg.sender, quantityHodl, 0);
        }
    }

    /**************************************************************************************
     * Buy HodlC from sell orders, or if no sell orders, from reserve. Lastly, open a 
     * buy order is the reserve is sold out.
     * Selectable low gas protects against future EVM price changes.
     * Completes as much as possible (gas) and returns unspent Eth.
     **************************************************************************************/ 

    function buyHodlC(uint amountEth, uint lowGas) external accrueByTime ifRunning returns(bytes32 orderId) {
        emit BuyHodlCRequested(msg.sender, amountEth, lowGas);
        uint orderLimit = orderLimit();         
        uint orderUsd = convertEthToUsd(amountEth);
        require(orderUsd >= MIN_ORDER_USD, "HodlDex, < min USD ");
        require(orderUsd <= orderLimit || orderLimit == 0, "HodlDex, > max USD");
        amountEth = _fillSellOrders(amountEth, lowGas);
        amountEth = _buyFromReserve(amountEth);
        orderId = _openBuyOrder(amountEth);
    }

    function _fillSellOrders(uint amountEth, uint lowGas) private returns(uint remainingEth) {
        bytes32 orderId;
        address orderSeller;        
        uint orderEth;
        uint orderHodl;
        uint orderAsk;
        uint txnEth;
        uint txnUsd;
        uint txnHodl; 
        uint ordersFilled;

        while(sellOrderIdFifo.count() > 0 && amountEth > 0) {
            if(gasleft() < lowGas) {
                emit IncreaseGas(msg.sender, gasleft(), ordersFilled);
                return 0;
            }
            orderId = sellOrderIdFifo.first();
            SellOrder storage o = sellOrder[orderId];
            orderSeller = o.seller;
            orderHodl = o.volumeHodl; 
            orderAsk = o.askUsd;
            orderEth = _convertUsdToEth((orderHodl.mul(orderAsk)).div(PRECISION));
            
            if(orderEth == 0) {
                // Order is now too small to fill. Refund hodl and prune.
                if(orderHodl > 0) {
                    emit SellOrderRefunded(msg.sender, orderId, orderHodl);
                    balance.add(HODL_ASSET, orderSeller, orderHodl, 0);
                    balance.sub(HODL_ASSET, orderSeller, 0, orderHodl);
                }
                delete sellOrder[orderId];
                sellOrderIdFifo.remove(orderId);
            } else {                        
                txnEth = amountEth;
                txnUsd = convertEthToUsd(txnEth);
                txnHodl = txnUsd.mul(PRECISION).div(orderAsk);
                if(orderEth < txnEth) {
                    txnEth = orderEth;
                    txnHodl = orderHodl;
                }
                emit SellOrderFilled(msg.sender, orderId, orderSeller, txnEth, txnHodl);
                balance.sub(ETH_ASSET, msg.sender, txnEth, 0);
                balance.add(ETH_ASSET, orderSeller, txnEth, 0);
                balance.add(HODL_ASSET, msg.sender, txnHodl, 0);
                balance.sub(HODL_ASSET, orderSeller, 0, txnHodl);
                amountEth = amountEth.sub(txnEth, "HodlDex 503"); 

                if(orderHodl == txnHodl) {
                    delete sellOrder[orderId];
                    sellOrderIdFifo.remove(orderId);
                } else {
                    o.volumeHodl = o.volumeHodl.sub(txnHodl, "HodlDex 504");
                }
                ordersFilled++;
                _increaseTransactionCount(1);
            }
        }
        remainingEth = amountEth;
    }

    function _buyFromReserve(uint amountEth) private returns(uint remainingEth) {
        uint txnHodl;
        uint txnEth;
        uint reserveHodlBalance;
        if(amountEth > 0) {
            uint amountHodl = _convertEthToHodl(amountEth);
            reserveHodlBalance = balance.balanceOf(HODL_ASSET, address(this));
            txnHodl = (amountHodl <= reserveHodlBalance) ? amountHodl : reserveHodlBalance;
            if(txnHodl > 0) {
                txnEth = _convertHodlToEth(txnHodl);
                emit BuyFromReserve(msg.sender, txnEth, txnHodl);
                balance.sub(HODL_ASSET, address(this), txnHodl, 0);
                balance.add(HODL_ASSET, msg.sender, txnHodl, 0);
                balance.sub(ETH_ASSET, msg.sender, txnEth, 0);
                balance.increaseDistribution(ETH_ASSET, txnEth);
                amountEth = amountEth.sub(txnEth, "HodlDex 505");
                _increaseTransactionCount(1);
            }
        }
        remainingEth = amountEth;
    }

    function _openBuyOrder(uint amountEth) private returns(bytes32 orderId) {
        // do not allow low gas to open a small buy order or buy orders to exist while sell orders exist
        if(convertEthToUsd(amountEth) > MIN_ORDER_USD && sellOrderIdFifo.count() == 0) {
            orderId = keyGen();
            emit BuyOrderOpened(orderId, msg.sender, amountEth);
            BuyOrder storage o = buyOrder[orderId];
            buyOrderIdFifo.append(orderId);
            balance.sub(ETH_ASSET, msg.sender, amountEth, 0);
            o.bidEth = amountEth;
            o.buyer = msg.sender;
        }
    }
    
    /**************************************************************************************
     * Cancel orders
     **************************************************************************************/ 

    function cancelSell(bytes32 orderId) external ifRunning {
        uint volHodl;
        address orderSeller;
        emit SellOrderCancelled(msg.sender, orderId);
        SellOrder storage o = sellOrder[orderId];
        orderSeller = o.seller;
        require(o.seller == msg.sender, "HodlDex, not seller.");
        volHodl = o.volumeHodl;
        balance.add(HODL_ASSET, msg.sender, volHodl, 0);
        sellOrderIdFifo.remove(orderId);
        balance.sub(HODL_ASSET, orderSeller, 0, volHodl);
        delete sellOrder[orderId];
    }
    function cancelBuy(bytes32 orderId) external ifRunning {
        BuyOrder storage o = buyOrder[orderId];
        emit BuyOrderCancelled(msg.sender, orderId);
        require(o.buyer == msg.sender, "HodlDex, not buyer.");
        balance.add(ETH_ASSET, msg.sender, o.bidEth, 0);
        buyOrderIdFifo.remove(orderId);
        delete buyOrder[orderId];
    }
    
    /**************************************************************************************
     * External quote
     **************************************************************************************/

    function _setEthToUsd() private returns(uint ethUsd18) {
        if(eth_usd_block == block.number) return ETH_USD;
        bool success;
        (ethUsd18, success) = getEthToUsd();
        ETH_USD = ethUsd18;
        eth_usd_block = block.number;
        if(!success) {
            error_count++;
            emit EthUsdError(msg.sender, error_count, ethUsd18);
        }
        emit SetEthUsd(msg.sender, ethUsd18);
        
        // minimize possible gaps in the distribution periods
        
        balance.poke(ETH_ASSET);
        balance.poke(HODL_ASSET);
    }

    function getEthToUsd() public view returns(uint ethUsd18, bool success) {
        try oracle.read() returns(uint response) {
            ethUsd18 = response;
            success = true;
        } catch {
            ethUsd18 = ETH_USD;
        }
    }

    /**************************************************************************************
     * Prices and quotes, persistent. UniSwap inspection once per block.
     **************************************************************************************/    
    
    function _convertEthToUsd(uint amtEth) private returns(uint inUsd) {
        return amtEth.mul(_setEthToUsd()).div(PRECISION);
    }
    
    function _convertUsdToEth(uint amtUsd) private returns(uint inEth) {
        return amtUsd.mul(PRECISION).div(_convertEthToUsd(PRECISION));
    }
    
    function _convertEthToHodl(uint amtEth) private returns(uint inHodl) {
        uint inUsd = _convertEthToUsd(amtEth);
        return convertUsdToHodl(inUsd);
    }
    
    function _convertHodlToEth(uint amtHodl) private returns(uint inEth) { 
        uint inUsd = convertHodlToUsd(amtHodl);
        return _convertUsdToEth(inUsd);
    }
    
    /**************************************************************************************
     * Prices and quotes, view only.
     **************************************************************************************/    
    
    function convertEthToUsd(uint amtEth) public view returns(uint inUsd) {
        return amtEth.mul(ETH_USD).div(PRECISION);
    }
   
    function convertUsdToEth(uint amtUsd) public view returns(uint inEth) {
        return amtUsd.mul(PRECISION).div(convertEthToUsd(PRECISION));
    }
    
    function convertHodlToUsd(uint amtHodl) public override view returns(uint inUsd) {
        (uint _hodlUsd, /* uint _accrualRate */) = rates();
        return amtHodl.mul(_hodlUsd).div(PRECISION);
    }
    
    function convertUsdToHodl(uint amtUsd) public override view returns(uint inHodl) {
         (uint _hodlUsd, /* uint _accrualRate */) = rates();
        return amtUsd.mul(PRECISION).div(_hodlUsd);
    }
    
    function convertEthToHodl(uint amtEth) public view returns(uint inHodl) {
        uint inUsd = convertEthToUsd(amtEth);
        return convertUsdToHodl(inUsd);
    }
    
    function convertHodlToEth(uint amtHodl) public view returns(uint inEth) { 
        uint inUsd = convertHodlToUsd(amtHodl);
        return convertUsdToEth(inUsd);
    }

    /**************************************************************************************
     * Fund Accounts
     **************************************************************************************/ 

    function depositEth() external ifRunning payable {
        require(msg.value > 0, "You must send Eth to this function");
        emit UserDepositEth(msg.sender, msg.value);
        balance.add(ETH_ASSET, msg.sender, msg.value, 0);
    }
    
    function withdrawEth(uint amount) external virtual ifRunning {
        emit UserWithdrawEth(msg.sender, amount);
        balance.sub(ETH_ASSET, msg.sender, amount, 0);
        msg.sender.call{ value: amount }; 
    }

    /**************************************************************************************
     * Daily accrual and rate decay over time
     **************************************************************************************/ 

    function rates() public view returns(uint hodlUsd, uint dailyAccrualRate) {
        hodlUsd = HODL_USD;
        dailyAccrualRate = DAILY_ACCRUAL_RATE;
        uint startTime = BIRTHDAY.add(SLEEP_TIME);
        if(now > startTime) {
            uint daysFromStart = (now.sub(startTime)) / 1 days;
            uint daysUnprocessed = daysFromStart.sub(accrualDaysProcessed);
            if(daysUnprocessed > 0) {
                hodlUsd = HODL_USD.mul(DAILY_ACCRUAL_RATE).div(PRECISION);
                dailyAccrualRate = DAILY_ACCRUAL_RATE.mul(DAILY_ACCRUAL_RATE_DECAY).div(PRECISION);
            }
        }
    }

    /**************************************************************************************
     * Stateful activity-based and time-based rate adjustments
     **************************************************************************************/

    function _increaseTransactionCount(uint transactionCount) private {
        if(transactionCount>0) {
            uint exBefore = HODL_USD;
            uint exAfter = exBefore.add(USD_TXN_ADJUSTMENT.mul(transactionCount));
            HODL_USD = exAfter;
            emit IncreasedByTransaction(msg.sender, transactionCount, exAfter);
        }
    }
    
    function increaseTransactionCount(uint transactionCount) external onlyOracle {
        _increaseTransactionCount(transactionCount);
    }
    
    function _accrueByTime() private returns(uint hodlUsdNow, uint dailyAccrualRateNow) {
        (hodlUsdNow, dailyAccrualRateNow) = rates();
        if(hodlUsdNow != HODL_USD || dailyAccrualRateNow != DAILY_ACCRUAL_RATE) { 
            HODL_USD = hodlUsdNow;
            DAILY_ACCRUAL_RATE = dailyAccrualRateNow; 
            accrualDaysProcessed = accrualDaysProcessed + 1; 
            emit AccrueByTime(msg.sender, hodlUsdNow, dailyAccrualRateNow);
        } 
    }
    
    /**************************************************************************************
     * View functions to enumerate the state
     **************************************************************************************/
    
    // Proportional Library reads this to compute userBal:supply ratio, always using hodl 
    function circulatingSupply() external view returns(uint circulating) {
        uint reserveBalance = balance.balanceOf(HODL_ASSET, address(this));
        return TOTAL_SUPPLY.sub(reserveBalance);
    }
    
    // Open orders, FIFO
    function sellOrderCount() public view returns(uint count) { 
        return sellOrderIdFifo.count(); 
    }
    function sellOrderFirst() public view returns(bytes32 orderId) { 
        return sellOrderIdFifo.first(); 
    }
    function sellOrderLast() public view returns(bytes32 orderId) { 
        return sellOrderIdFifo.last(); 
    }  
    function sellOrderIterate(bytes32 orderId) public view returns(bytes32 idBefore, bytes32 idAfter) { 
        return(sellOrderIdFifo.previous(orderId), sellOrderIdFifo.next(orderId)); 
    }
    function buyOrderCount() public view returns(uint count) { 
        return buyOrderIdFifo.count(); 
    }
    function buyOrderFirst() public view returns(bytes32 orderId) { 
        return buyOrderIdFifo.first(); 
    }
    function buyOrderLast() public view returns(bytes32 orderId) { 
        return buyOrderIdFifo.last(); 
    }    
    function buyOrderIterate(bytes32 orderId) public view returns(bytes32 idBefore, bytes32 idAfter) { 
        return(buyOrderIdFifo.previous(orderId), buyOrderIdFifo.next(orderId)); 
    }

    function user(address userAddr) public override view returns(uint balanceEth, uint balanceHodl, uint controlledHodl) {
        return(
            balance.balanceOf(ETH_ASSET, userAddr),
            balance.balanceOf(HODL_ASSET, userAddr),
            balance.additionalControlled(HODL_ASSET, userAddr));
    }
    function isAccruing() public view returns(bool accruing) {
        return now > BIRTHDAY.add(SLEEP_TIME);
    }
    function isConfigured() public view returns(bool initialized) {
        return address(oracle) != UNDEFINED;
    }
    function isRunning() public view returns(bool running) {
        return getRoleMemberCount(MIGRATION_ROLE) == 0;
    }
    function orderLimit() public view returns(uint limitUsd) {
        (uint askUsd, /* uint accrualRate */) = rates();
        return (askUsd > MAX_THRESHOLD_USD) ? 0 : MAX_ORDER_FACTOR * askUsd;
    }
    
    /**************************************************************************************
     * Explore the Proportional Distribution State and internal User Balance History
     **************************************************************************************/ 
    
    function period() external view returns(uint _period) {
        return balance.period();
    }

    // The next unclaimed distribution that will be processed when the user claims it.

    function nextUserDistributionDetails(address userAddr, bytes32 assetId) external view returns(
        uint amount,
        uint balanceIndex,
        uint distributionIndex,
        bool closed)
    {
        (amount, balanceIndex, distributionIndex, closed) = balance.nextUserDistributionDetails(assetId, userAddr);
    }

    function distributionCount(bytes32 assetId) external view returns(uint count) {
        count = balance.distributionCount(assetId);
    }

    function distributionAtIndex(bytes32 assetId, uint index) external view returns(uint denominator, uint amount, uint _period) {
        return balance.distributionAtIndex(assetId, index);
    }

    // User balance history

    function userBalanceCount(bytes32 assetId, address userAddr) external view returns(uint count) {
        return balance.userBalanceCount(assetId, userAddr);
    }

    function userBalanceAtIndex(bytes32 assetId, address userAddr, uint index) external view returns(uint userBalance, uint controlled, uint _period) {
        return balance.userBalanceAtIndex(assetId, userAddr, index);
    }

    /**************************************************************************************
     * Initialization functions that support data migration
     **************************************************************************************/  
     
    function init(IHTokenReserve _tokenReserve, IHOracle _oracle) external initializer() {
        
        accrualDaysProcessed = _accrualDaysProcessed;
        HODL_USD = _HODL_USD;
        DAILY_ACCRUAL_RATE = _DAILY_ACCRUAL_RATE;

        assetIds.push(HODL_ASSET);
        assetIds.push(ETH_ASSET);
        
        // initialize Proportional Assets
        balance.init(assetIds, HODL_ASSET, now, DISTRIBUTION_PERIOD, address(this));
        
        // assign the total hodlc supply to the hodlc reserve
        balance.add(HODL_ASSET, address(this), TOTAL_SUPPLY, 0);
        
        // contract instances
        oracle = _oracle;
        tokenReserve = _tokenReserve;       
        
        // configure access control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(ORACLE_ROLE, msg.sender);
        _setupRole(MIGRATION_ROLE, msg.sender);
        _setupRole(RESERVE_ROLE, address(_tokenReserve));
        
        emit InitConfigure(msg.sender, _tokenReserve, _oracle); 
    }

    function initSetDailyAccrualRate(uint rateAsDecimal18) external onlyMigration {
        DAILY_ACCRUAL_RATE = rateAsDecimal18;
        emit SetDailyAccrualRate(msg.sender, rateAsDecimal18);
    }    

    function initUser(address userAddr, uint hodl) external onlyMigration payable {
        balance.add(ETH_ASSET, userAddr, msg.value, 0);
        balance.add(HODL_ASSET, userAddr, hodl, 0);
        balance.sub(HODL_ASSET, address(this), hodl, 0);
        emit UserInitialized(msg.sender, userAddr, hodl, msg.value);
    }
    
    function initResetUser(address userAddr) external virtual onlyMigration {
        emit UserUninitialized(msg.sender, userAddr);
        balance.add(HODL_ASSET, address(this), balance.balanceOf(HODL_ASSET, userAddr), 0);
        balance.sub(HODL_ASSET, userAddr, balance.balanceOf(HODL_ASSET, userAddr), 0);
        balance.sub(ETH_ASSET, userAddr, balance.balanceOf(ETH_ASSET, userAddr), 0);
        if(balance.balanceOf(ETH_ASSET, userAddr) > 0) msg.sender.call{ value: balance.balanceOf(ETH_ASSET, userAddr) };
    }
    
    // Revoking the last Migration_Role member starts trading (isRunning). Ensure backup ETH_USD is set.
    function revokeRole(bytes32 role, address account) public override {
        require(ETH_USD > 0, "HodlDex, Set EthUsd");
        AccessControl.revokeRole(role, account);
    }
}

