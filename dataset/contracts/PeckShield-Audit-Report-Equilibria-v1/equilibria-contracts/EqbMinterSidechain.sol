// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./EqbMinterBaseUpg.sol";

contract EqbMinterSidechain is EqbMinterBaseUpg {
    uint256 public factor;

    event FactorUpdated(uint256 _factor);
    event MintedAmountBroadcasted(uint256[] _chainIds, uint256 _amount);

    function initialize(
        address _eqb,
        address _eqbMsgSendEndpoint,
        uint256 _approxDstExecutionGas,
        address _eqbMsgReceiveEndpoint
    ) public initializer {
        __EqbMinterBase_init(
            _eqb,
            _eqbMsgSendEndpoint,
            _approxDstExecutionGas,
            _eqbMsgReceiveEndpoint
        );

        factor = DENOMINATOR;
        emit FactorUpdated(DENOMINATOR);
    }

    function broadcastMintedAmount(
        uint256[] calldata _chainIds
    ) public payable refundUnusedEth {
        if (_chainIds.length == 0) {
            revert Errors.ArrayEmpty();
        }
        for (uint256 i = 0; i < _chainIds.length; i++) {
            _sendMessage(_chainIds[i], abi.encode(mintedAmount));
        }
        emit MintedAmountBroadcasted(_chainIds, mintedAmount);
    }

    function _executeMessage(
        uint256,
        address,
        bytes memory _message
    ) internal override {
        factor = abi.decode(_message, (uint256));
        emit FactorUpdated(factor);
    }

    function getFactor() public view override returns (uint256) {
        return factor;
    }
}
