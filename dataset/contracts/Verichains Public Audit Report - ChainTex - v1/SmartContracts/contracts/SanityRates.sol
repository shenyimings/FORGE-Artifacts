pragma solidity 0.4.25;


import "./TRC20Interface.sol";
import "./Withdrawable.sol";
import "./Utils.sol";
import "./SanityRatesInterface.sol";


contract SanityRates is SanityRatesInterface, Withdrawable, Utils {
    mapping(address=>uint) public tokenRate;
    mapping(address=>uint) public reasonableDiffInBps;

    constructor(address _admin) public {
        require(_admin != address(0));
        admin = _admin;
    }

    function setReasonableDiff(TRC20[] memory srcs, uint[] memory diff) public onlyAdmin {
        require(srcs.length == diff.length);
        for (uint i = 0; i < srcs.length; i++) {
            require(diff[i] <= 100 * 100);
            reasonableDiffInBps[srcs[i]] = diff[i];
        }
    }

    function setSanityRates(TRC20[] memory srcs, uint[] memory rates) public onlyOperator {
        require(srcs.length == rates.length);

        for (uint i = 0; i < srcs.length; i++) {
            require(rates[i] <= MAX_RATE);
            tokenRate[srcs[i]] = rates[i];
        }
    }

    function getSanityRate(TRC20 src, TRC20 dest) public view returns(uint) {
        if (src != TOMO_TOKEN_ADDRESS && dest != TOMO_TOKEN_ADDRESS) return 0;

        uint rate;
        address token;
        if (src == TOMO_TOKEN_ADDRESS) {
            rate = (PRECISION*PRECISION)/tokenRate[dest];
            token = dest;
        } else {
            rate = tokenRate[src];
            token = src;
        }

        return rate * (10000 + reasonableDiffInBps[token])/10000;
    }
}
