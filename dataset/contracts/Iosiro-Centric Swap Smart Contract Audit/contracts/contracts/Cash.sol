pragma solidity 0.4.25;

import './SafeMath.sol';
import './TRC20.sol';


contract Cash is TRC20Detailed {
    address public riseContract;

    constructor(address _mintSaver) public TRC20Detailed('Centric CASH', 'CNS', 8) {
        _mint(_mintSaver, 0);
    }

    modifier onlyRise() {
        require(msg.sender == riseContract, 'CALLER_MUST_BE_RISE_CONTRACT_ONLY');
        _;
    }

    function setRiseContract(address _riseContractAddress) external onlyContractOwner() {
        require(_riseContractAddress != address(0), 'RISE_CONTRACT_CANNOTBE_NULL_ADDRESS');
        require(riseContract == address(0), 'RISE_CONTRACT_ADDRESS_IS_ALREADY_SET');
        riseContract = _riseContractAddress;
    }

    function mintFromRise(address to, uint256 value) external onlyRise returns (bool _success) {
        _mint(to, value);
        return true;
    }

    function burnFromRise(address tokensOwner, uint256 value)
        external
        onlyRise
        returns (bool _success)
    {
        _burn(tokensOwner, value);
        return true;
    }
}
