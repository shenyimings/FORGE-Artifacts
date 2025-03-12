pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../Proxy.sol";
import "./debug/GasProfiler.sol";

contract ProxyMock is Proxy, GasProfiler {
    constructor(address registry) public Proxy(registry) {}

    event RecordHandlerResult(bytes value);

    function execMock(address to, bytes memory data)
        public
        payable
        returns (bytes memory result)
    {
        _preProcess();
        _setBase();
        result = _exec(to, data);
        _setPostProcess(to);
        _deltaGas("Gas");
        _postProcess();
        emit RecordHandlerResult(result);
        return result;
    }

    function _preProcess() internal override isCubeCounterZero {
        // Set the sender.
        _setSender();
    }

    function updateTokenMock(address token) public {
        stack.setAddress(token);
    }
}
