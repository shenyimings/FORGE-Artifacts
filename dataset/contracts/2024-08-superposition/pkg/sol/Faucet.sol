// SPDX-Identifier: MIT

pragma solidity 0.8.16;

import "./IFaucet.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external;
}

/*
* Faucet sends ERC20 tokens that were configured to be sent to addresses given.
*/
contract Faucet is IFaucet {
    /// @dev operator to use to send the amounts on request.
    address public operator_;

    /// @dev emergency council to use to "rescue" the funds at any point.
    address immutable EMERGENCY_COUNCIL;

    IERC20[] public tokens;

    uint256[] private amounts;

    uint256 private gasTokenAmount;

    constructor(
        address _operator,
        address _emergencyCouncil,
        IERC20[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _gasTokenAmount
    ) {
        operator_ = _operator;
        EMERGENCY_COUNCIL = _emergencyCouncil;
        tokens = _tokens;
        amounts = _amounts;
        gasTokenAmount = _gasTokenAmount;
    }

    receive() external payable {}

    /// @inheritdoc IFaucet
    function sendTo(FaucetReq[] calldata _requests) external {
        require(msg.sender == operator_, "only operator");
        for (uint i = 0; i < _requests.length; ++i) {
            address recipient = _requests[i].recipient;
            bool isStaker = _requests[i].isStaker;
            for (uint x = 0; x < tokens.length; ++x) {
                uint256 amount = amounts[x];
                if (isStaker) amount *= 5;
                tokens[x].transfer(recipient, amount);
            }
            if (gasTokenAmount > 0) {
                uint256 gas = gasTokenAmount;
                if (isStaker) gas *= 5;
                bool _rc = payable(recipient).send(gas);
            }
        }
    }

    function changeOperator(address _oldOperator, address _newOperator) external {
        require(operator_ == _oldOperator, "incorrect order");
        require(msg.sender == EMERGENCY_COUNCIL, "only council");
        operator_ = _newOperator;
    }
}
