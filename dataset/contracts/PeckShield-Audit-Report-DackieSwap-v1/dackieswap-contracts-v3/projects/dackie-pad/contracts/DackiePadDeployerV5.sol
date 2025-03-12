// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./DackiePadInitializableV5.sol";

/**
 * @title DackiePadDeployer
 */
contract DackiePadDeployerV5 is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_BUFFER_BLOCKS = 302400; // 302,400 blocks (about a week, 2s/block on Base)

    event AdminTokenRecovery(address indexed tokenRecovered, uint256 amount);
    event NewIDOContract(address indexed idoAddress);

    /**
     * @notice Constructor
     */
    constructor() public {
    }

    /**
     * @notice It creates the IDO contract and initializes the contract.
     * @param _raiseToken: the raise token used
     * @param _offeringToken: the token that is offered for the IDO
     * @param _startBlock: the start block for the IDO
     * @param _endBlock: the end block for the IDO
     * @param _adminAddress: the admin address for handling tokens
     */
    function createIDO(
        address _raiseToken,
        address _offeringToken,
        uint256 _startBlock,
        uint256 _endBlock,
        address _adminAddress
    ) external onlyOwner {
        require(IERC20(_raiseToken).totalSupply() >= 0);
        require(IERC20(_offeringToken).totalSupply() >= 0);
        require(_raiseToken != _offeringToken, "Operations: Tokens must be be different");
        require(_endBlock < (block.number + MAX_BUFFER_BLOCKS), "Operations: EndBlock too far");
        require(_startBlock < _endBlock, "Operations: StartBlock must be inferior to endBlock");
        require(_startBlock > block.number, "Operations: StartBlock must be greater than current block");
        bytes memory bytecode = type(DackiePadInitializableV5).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_raiseToken, _offeringToken, _startBlock));
        address idoAddress;
        assembly {
            idoAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        DackiePadInitializableV5(idoAddress).initialize(
            _raiseToken,
            _offeringToken,
            _startBlock,
            _endBlock,
            MAX_BUFFER_BLOCKS,
            _adminAddress
        );

        emit NewIDOContract(idoAddress);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress) external onlyOwner {
        uint256 balanceToRecover = IERC20(_tokenAddress).balanceOf(address(this));
        require(balanceToRecover > 0, "Operations: Balance must be > 0");
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), balanceToRecover);

        emit AdminTokenRecovery(_tokenAddress, balanceToRecover);
    }
}
