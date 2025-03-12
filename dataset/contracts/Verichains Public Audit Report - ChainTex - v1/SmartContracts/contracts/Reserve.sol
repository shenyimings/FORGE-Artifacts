pragma solidity 0.4.25;


import "./TRC20Interface.sol";
import "./Utils.sol";
import "./Withdrawable.sol";
import "./ConversionRatesInterface.sol";
import "./SanityRatesInterface.sol";
import "./ReserveInterface.sol";

/// @title Reserve contract
contract Reserve is ReserveInterface, Withdrawable, Utils {

    address public network;
    bool public tradeEnabled;
    ConversionRatesInterface public conversionRatesContract;
    SanityRatesInterface public sanityRatesContract;
    mapping(bytes32=>bool) public approvedWithdrawAddresses; // sha3(token,address)=>bool

    constructor(address _network, ConversionRatesInterface _ratesContract, address _admin) public {
        require(_admin != address(0));
        require(_ratesContract != address(0));
        require(_network != address(0));
        network = _network;
        conversionRatesContract = _ratesContract;
        admin = _admin;
        tradeEnabled = true;
    }

    event DepositToken(TRC20 token, uint amount);

    function() public payable {
        emit DepositToken(TOMO_TOKEN_ADDRESS, msg.value);
    }

    event TradeExecute(
        address indexed origin,
        address src,
        uint srcAmount,
        address destToken,
        uint destAmount,
        address destAddress
    );

    function trade(
        TRC20 srcToken,
        uint srcAmount,
        TRC20 destToken,
        address destAddress,
        uint conversionRate,
        uint feeInWei,
        bool validate
    )
        public
        payable
        returns(bool)
    {
        require(tradeEnabled, "Reserve (Trade): Trade is not enabled");
        require(msg.sender == network, "Reserve (Trade): Sender must be Network");

        require(doTrade(srcToken, srcAmount, destToken, destAddress, conversionRate, validate));
        // transfer fee to network contract
        if (feeInWei > 0) { network.transfer(feeInWei); }

        return true;
    }

    event TradeEnabled(bool enable);

    function enableTrade() public onlyAdmin returns(bool) {
        tradeEnabled = true;
        emit TradeEnabled(true);

        return true;
    }

    function disableTrade() public onlyAlerter returns(bool) {
        tradeEnabled = false;
        emit TradeEnabled(false);

        return true;
    }

    event WithdrawAddressApproved(TRC20 token, address addr, bool approve);

    function approveWithdrawAddress(TRC20 token, address addr, bool approve) public onlyAdmin {
        approvedWithdrawAddresses[keccak256(abi.encodePacked(token, addr))] = approve;
        emit WithdrawAddressApproved(token, addr, approve);

        setDecimals(token);
    }

    event WithdrawFunds(TRC20 token, uint amount, address destination);

    function withdraw(TRC20 token, uint amount, address destination) public onlyOperator returns(bool) {
        require(approvedWithdrawAddresses[keccak256(abi.encodePacked(token, destination))]);

        if (token == TOMO_TOKEN_ADDRESS) {
            destination.transfer(amount);
        } else {
            require(token.transfer(destination, amount));
        }

        emit WithdrawFunds(token, amount, destination);

        return true;
    }

    event SetContractAddresses(address network, address rate, address sanity);

    function setContracts(
        address _network,
        ConversionRatesInterface _conversionRates,
        SanityRatesInterface _sanityRates
    )
        public
        onlyAdmin
    {
        require(_network != address(0), "Reserve (setContracts): network must be set");
        require(_conversionRates != address(0), "Reserve (setContracts): conversionRate must be set");

        network = _network;
        conversionRatesContract = _conversionRates;
        sanityRatesContract = _sanityRates;

        emit SetContractAddresses(network, conversionRatesContract, sanityRatesContract);
    }

    ////////////////////////////////////////////////////////////////////////////
    /// status functions ///////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    function getBalance(TRC20 token) public view returns(uint) {
        if (token == TOMO_TOKEN_ADDRESS)
            return address(this).balance;
        else {
            return token.balanceOf(address(this));
        }
    }

    function getDestQty(TRC20 src, TRC20 dest, uint srcQty, uint rate) public view returns(uint) {
        uint dstDecimals = getDecimals(dest);
        uint srcDecimals = getDecimals(src);

        return calcDstQty(srcQty, srcDecimals, dstDecimals, rate);
    }

    function getSrcQty(TRC20 src, TRC20 dest, uint dstQty, uint rate) public view returns(uint) {
        uint dstDecimals = getDecimals(dest);
        uint srcDecimals = getDecimals(src);

        return calcSrcQty(dstQty, srcDecimals, dstDecimals, rate);
    }

    function getConversionRate(TRC20 src, TRC20 dest, uint srcQty, uint blockNumber) public view returns(uint) {
        TRC20 token;
        bool  isBuy;

        if (!tradeEnabled) return 0;

        if (TOMO_TOKEN_ADDRESS == src) {
            isBuy = true;
            token = dest;
        } else if (TOMO_TOKEN_ADDRESS == dest) {
            isBuy = false;
            token = src;
        } else {
            return 0; // pair is not listed
        }

        uint rate = conversionRatesContract.getRate(token, blockNumber, isBuy, srcQty);
        uint destQty = getDestQty(src, dest, srcQty, rate);

        if (getBalance(dest) < destQty) return 0;

        if (sanityRatesContract != address(0)) {
            uint sanityRate = sanityRatesContract.getSanityRate(src, dest);
            if (rate > sanityRate) return 0;
        }

        return rate;
    }

    /// @dev do a trade
    /// @param srcToken Src token
    /// @param srcAmount Amount of src token
    /// @param destToken Destination token
    /// @param destAddress Destination address to send tokens to
    /// @param validate If true, additional validations are applicable
    /// @return true iff trade is successful
    function doTrade(
        TRC20 srcToken,
        uint srcAmount,
        TRC20 destToken,
        address destAddress,
        uint conversionRate,
        bool validate
    )
        internal
        returns(bool)
    {
        // can skip validation if done at kyber network level
        if (validate) {
            require(conversionRate > 0, "Reserve (doTrade): conversionRate must be > 0");
            if (srcToken == TOMO_TOKEN_ADDRESS)
                require(msg.value == srcAmount, "Reserve (doTrade): srcAmount must be equal tomo value");
            else
                require(msg.value == 0, "Reserve (doTrade): Tomo value must be zero");
        }

        uint destAmount = getDestQty(srcToken, destToken, srcAmount, conversionRate);
        // sanity check
        require(destAmount > 0, "Reserve (doTrade): destAmount must be > 0");

        // add to imbalance
        TRC20 token;
        int tradeAmount;
        if (srcToken == TOMO_TOKEN_ADDRESS) {
            tradeAmount = int(destAmount);
            token = destToken;
        } else {
            tradeAmount = -1 * int(srcAmount);
            token = srcToken;
        }

        conversionRatesContract.recordImbalance(
            token,
            tradeAmount,
            0,
            block.number
        );

        // collect src tokens
        if (srcToken != TOMO_TOKEN_ADDRESS) {
            require(srcToken.transferFrom(msg.sender, this, srcAmount));
        }

        // send dest tokens
        if (destToken == TOMO_TOKEN_ADDRESS) {
            destAddress.transfer(destAmount);
        } else {
            require(destToken.transfer(destAddress, destAmount));
        }

        emit TradeExecute(msg.sender, srcToken, srcAmount, destToken, destAmount, destAddress);

        return true;
    }
}
