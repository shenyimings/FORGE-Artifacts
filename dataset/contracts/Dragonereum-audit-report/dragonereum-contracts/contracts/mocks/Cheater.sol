pragma solidity 0.4.25;

/* solium-disable security/no-inline-assembly */
/* solium-disable security/no-call-value */
/* solium-disable security/no-low-level-calls */

contract Cheater {
    address public target;

    constructor(address _target) public {
        target = _target;
    }

    function callCreateGoldSellOrder(uint price, uint amount) public returns(bool) {
        bool result = target.call(abi.encodeWithSignature("createGoldSellOrder(uint256,uint256)", price, amount));
        assembly {
            let size := returndatasize
            returndatacopy(0x40, 0, size)
            if iszero(result) {
                revert(0x40, size)
            }
        }
    }

    function raiseError() internal pure {
        assembly {
            let size := returndatasize
            returndatacopy(0x40, 0, size)
            revert(0x40, size)
        }
    }

    function callFillGoldSellOrder(address seller, uint price, uint amount) public returns(bool) {
        bool result = target.call(abi.encodeWithSignature("fillGoldSellOrder(address,uint256,uint256)", seller, price, amount));
        assembly {
            let size := returndatasize
            returndatacopy(0x40, 0, size)
            if iszero(result) {
                revert(0x40, size)
            }
        }
        return true;
    }

    function callCancelGoldSellOrder() public returns(bool) {
        bool result = target.call(abi.encodeWithSignature("cancelGoldSellOrder()"));
        assembly {
            let size := returndatasize
            returndatacopy(0x40, 0, size)
            if iszero(result) {
                revert(0x40, size)
            }
        }
    }

    function callSellEgg() public returns(bool) {
        uint256 id = 1;
        uint256 maxPrice = 2000;
        uint256 minPrice = 1000;
        uint16 period = 1;
        bool isGold = true;
        bool result = target.call(
            abi.encodeWithSignature("sellEgg(uint256,uint256,uint256,uint16,bool)", id, maxPrice, minPrice, period, isGold)
        );
        if (!result) raiseError();
        return true;
    }

    function callBuyEgg() public returns(bool) {
        uint256 id = 1;
        uint256 expectedPrice = 100;
        bool isGold = false;
        bool result = target.call(abi.encodeWithSignature("buyEgg(uint256,uint256,bool)", id, expectedPrice, isGold));
        if (!result) raiseError();
        return true;
    }
}
