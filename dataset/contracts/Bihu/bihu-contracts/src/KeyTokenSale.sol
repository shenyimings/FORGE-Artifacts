// Copyright (C) 2017 DappHub, LLC

pragma solidity ^0.4.11;

import "ds-token/token.sol";
import "ds-exec/exec.sol";
import "ds-auth/auth.sol";
import "ds-note/note.sol";
import "ds-math/math.sol";

contract KeyTokenSale is DSStop, DSMath, DSExec {

    DSToken public key;

    // KEY PRICES (ETH/KEY)
    uint128 public constant PUBLIC_SALE_PRICE = 200000 ether;

    uint128 public constant TOTAL_SUPPLY = 10 ** 11 * 1 ether;  // 100 billion KEY in total

    uint128 public constant SELL_SOFT_LIMIT = TOTAL_SUPPLY * 12 / 100; // soft limit is 12% , 60000 eth
    uint128 public constant SELL_HARD_LIMIT = TOTAL_SUPPLY * 16 / 100; // hard limit is 16% , 80000 eth

    uint128 public constant FUTURE_DISTRIBUTE_LIMIT = TOTAL_SUPPLY * 84 / 100; // 84% for future distribution

    uint128 public constant USER_BUY_LIMIT = 500 ether; // 500 ether limit
    uint128 public constant MAX_GAS_PRICE = 50000000000;  // 50GWei

    uint public startTime;
    uint public endTime;

    bool public moreThanSoftLimit;

    mapping (address => uint)  public  userBuys; // limit to 500 eth

    address public destFoundation; //multisig account , 4-of-6

    uint128 public sold;
    uint128 public constant soldByChannels = 40000 * 200000 ether; // 2 ICO websites, each 20000 eth

    function KeyTokenSale(uint startTime_, address destFoundation_) {

        key = new DSToken("KEY");

        destFoundation = destFoundation_;

        startTime = startTime_;
        endTime = startTime + 14 days;

        sold = soldByChannels; // sold by 3rd party ICO websites;
        key.mint(TOTAL_SUPPLY);

        key.transfer(destFoundation, FUTURE_DISTRIBUTE_LIMIT);
        key.transfer(destFoundation, soldByChannels);

        //disable transfer
        key.stop();
    }

    // overrideable for easy testing
    function time() constant returns (uint) {
        return now;
    }

    function isContract(address _addr) constant internal returns(bool) {
        uint size;
        if (_addr == 0) return false;
        assembly {
        size := extcodesize(_addr)
        }
        return size > 0;
    }

    function canBuy(uint total) returns (bool) {
        return total <= USER_BUY_LIMIT;
    }

    function() payable stoppable note {

//        require(!isContract(msg.sender));
        require(msg.value >= 0.01 ether);
        require(tx.gasprice <= MAX_GAS_PRICE);

        assert(time() >= startTime && time() < endTime);

        var toFund = cast(msg.value);

        var requested = wmul(toFund, PUBLIC_SALE_PRICE);

        // selling SELL_HARD_LIMIT tokens ends the sale
        if( add(sold, requested) >= SELL_HARD_LIMIT) {
            requested = SELL_HARD_LIMIT - sold;
            toFund = wdiv(requested, PUBLIC_SALE_PRICE);

            endTime = time();
        }

        // User cannot buy more than USER_BUY_LIMIT
        var totalUserBuy = add(userBuys[msg.sender], toFund);
        assert(canBuy(totalUserBuy));
        userBuys[msg.sender] = totalUserBuy;

        sold = hadd(sold, requested);

        // Soft limit triggers the sale to close in 24 hours
        if( !moreThanSoftLimit && sold >= SELL_SOFT_LIMIT ) {
            moreThanSoftLimit = true;
            endTime = time() + 24 hours; // last 24 hours after soft limit,
        }

        key.start();
        key.transfer(msg.sender, requested);
        key.stop();

        exec(destFoundation, toFund); // send collected ETH to multisig

        // return excess ETH to the user
        uint toReturn = sub(msg.value, toFund);
        if(toReturn > 0) {
            exec(msg.sender, toReturn);
        }
    }

    function setStartTime(uint startTime_) auth note {
        require(time() <= startTime && time() <= startTime_);

        startTime = startTime_;
        endTime = startTime + 14 days;
    }

    function finalize() auth note {
        require(time() >= endTime);

        // enable transfer
        key.start();

        // transfer undistributed KEY
        key.transfer(destFoundation, key.balanceOf(this));

        // owner -> destFoundation
        key.setOwner(destFoundation);
    }


    // @notice This method can be used by the controller to extract mistakenly
    //  sent tokens to this contract.
    // @param dst The address that will be receiving the tokens
    // @param wad The amount of tokens to transfer
    // @param _token The address of the token contract that you want to recover
    function transferTokens(address dst, uint wad, address _token) public auth note {
        ERC20 token = ERC20(_token);
        token.transfer(dst, wad);
    }

    function summary()constant returns(
        uint128 _sold,
        uint _startTime,
        uint _endTime)
        {
        _sold = sold;
        _startTime = startTime;
        _endTime = endTime;
        return;
    }

}
