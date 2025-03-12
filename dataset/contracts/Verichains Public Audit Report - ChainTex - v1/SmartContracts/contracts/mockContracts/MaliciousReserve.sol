pragma solidity 0.4.25;


import "../Reserve.sol";
import "../NetworkProxyInterface.sol";

contract MaliciousReserve is Reserve {

    NetworkProxyInterface proxy;
    address public scammer;
    TRC20 public scamToken;

    uint public numRecursive = 1;

    constructor(address _network, ConversionRatesInterface _ratesContract, address _admin)
        Reserve(_network, _ratesContract, _admin) public
    {

    }

    function trade(
        TRC20 srcToken,
        uint srcAmount,
        TRC20 destToken,
        address destAddress,
        uint conversionRate,
        bool validate
    )
        public
        payable
        returns(bool)
    {
        require(tradeEnabled);
        require(msg.sender == network);

        require(srcToken == TOMO_TOKEN_ADDRESS);

        if (numRecursive > 0) {
            --numRecursive;

            doTrade();
        }

        require(doTrade(srcToken, srcAmount, destToken, destAddress, conversionRate, validate));

        return true;
    }

    function setNetworkProxy(NetworkProxyInterface _proxy) public {

        require(_proxy != address(0));

        proxy = _proxy;
    }

    function doTrade () public {
        uint callValue = 341;

        TRC20 srcToken = TRC20(TOMO_TOKEN_ADDRESS);
        proxy.swap.value(callValue)(srcToken, callValue, scamToken, scammer, (2 ** 255), 0, 0);
    }

    function setDestAddress(address _scammer) public {
        require(_scammer != address(0));
        scammer = _scammer;
    }

    function setDestToken (TRC20 _token) public {
        scamToken = _token;
    }

    function setNumRecursive(uint num)  public {
        numRecursive = num;
    }
}
