// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "synthetix/contracts/Synth.sol";
import "synthetix/contracts/MultiCollateralSynth.sol";
import "synthetix/contracts/TokenState.sol";

// Synthetix contracts mocks

contract SynthProxyMock {
    function() external { }
}

contract SynthMockBase is Synth {
    function _ensureCanTransfer(address, uint) internal view {
        return;
    }

    function mint(address _to, uint256 _amount) public returns (bool) {
        require(msg.sender == Owned.owner);
        totalSupply = totalSupply.add(_amount);
        uint256 newBalance = tokenState.balanceOf(_to).add(_amount);
        tokenState.setBalanceOf(_to, newBalance);
        return true;
    }

    function _stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function _getNewProxy() internal returns (address payable) {
        return address(uint160(address(new SynthProxyMock())));
    }

    function _getNewTokenState() internal returns (TokenState) {
        return new TokenState(address(this), address(this));
    }
}

contract SynthMock is SynthMockBase {
    constructor(string memory _tokenName,
        string memory _tokenSymbol,
        address _owner) public Synth(_getNewProxy(), _getNewTokenState(), _tokenName, _tokenSymbol, _owner, _stringToBytes32(_tokenSymbol), 0, _owner) { }
}

contract MultiCollateralSynthMock is MultiCollateralSynth, SynthMockBase {
    constructor(string memory _tokenName,
        string memory _tokenSymbol,
        address _owner) public MultiCollateralSynth(_getNewProxy(), _getNewTokenState(), _tokenName, _tokenSymbol, _owner, _stringToBytes32(_tokenSymbol), 0, _owner) { }
}
