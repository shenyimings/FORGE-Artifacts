// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract HezMaticMerge is Ownable {
    using SafeERC20 for IERC20; 

    // bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")));
    bytes4 constant _PERMIT_SIGNATURE = 0xd505accf;
    
    // Swap ratio from HEZ to MATIC multiplied by 1000
    uint256 public constant SWAP_RATIO = 3500;

    // HEZ token address
    IERC20 public immutable hez;

    // MATIC token address
    IERC20 public immutable matic;
    
    // UNIX time in seconds when the owner will be able to withdraw the remaining MATIC tokens
    uint256 public withdrawTimeout;

    /**
     * @dev Emitted when someone swap HEZ for MATIC
     */
    event HezToMatic(uint256 hezAmount, uint256 maticAmount, address indexed grantee);

    /**
     * @dev Emitted when the owner increases the timeout
     */
    event NewWithdrawTimeout(uint256 newWithdrawTimeout);

    /**
     * @dev Emitted when the owner withdraw tokens
     */
    event WithdrawTokens(address tokenAddress, uint256 amount);

    /**
     * @dev This contract will receive MATIC tokens, the users will be able to swap their HEZ tokens for MATIC tokens
     *      as long as this contract holds enough amount. The swapped HEZ tokens will be burned.
     *      Once the withdrawTimeout is reached, the owner will be able to withdraw the remaining MATIC tokens.
     * @param _hez HEZ token address
     * @param _matic MATIC token address
     * @param duration Time in seconds that the owner will not be able to withdraw the MATIC tokens
     */
    constructor (
        IERC20 _hez,
        IERC20 _matic,
        uint256 duration
    ){
        hez = _hez;
        matic = _matic;
        withdrawTimeout = block.timestamp + duration;
    }

    /**
     * @notice Method that allows swap HEZ for MATIC tokens at the ratio of 1 HEZ --> 3.5 MATIC
     * Users can either use the permit functionality, or approve previously the tokens and send an empty _permitData
     * @param hezAmount Amount of HEZ to swap
     * @param _permitData Raw data of the call `permit` of the token
     */
    function hezToMatic(uint256 hezAmount, bytes calldata _permitData) public {
        // receive and burn HEZ tokens
        if (_permitData.length != 0) {
            _permit(address(hez), hezAmount, _permitData);
        }

        hez.safeTransferFrom(msg.sender, address(this), hezAmount);
        ERC20Burnable(address(hez)).burn(hezAmount);

        // transfer MATIC tokens
        uint256 maticAmount = (hezAmount * SWAP_RATIO) / 1000;
        matic.safeTransfer(msg.sender, maticAmount);

        emit HezToMatic(hezAmount, maticAmount, msg.sender);
    }

    /**
     * @notice Method that allows the owner to withdraw any token from this contract
     * In order to withdraw MATIC tokens the owner must wait until the withdrawTimeout expires
     * @param tokenAddress Token address
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTokens(address tokenAddress, uint256 amount) public onlyOwner {
        if(tokenAddress == address(matic)) {
            require(
                block.timestamp > withdrawTimeout,
                "HezMaticMerge::withdrawTokens: TIMEOUT_NOT_REACHED"
            );
        }
        
        IERC20(tokenAddress).safeTransfer(owner(), amount);

        emit WithdrawTokens(tokenAddress, amount);
    }

    /**
     * @notice Method that allows the owner to increase the withdraw timeout
     * @param newWithdrawTimeout new withdraw timeout
     */
    function setWithdrawTimeout(uint256 newWithdrawTimeout) public onlyOwner {
        require(
            newWithdrawTimeout > withdrawTimeout,
             "HezMaticMerge::setWithdrawTimeout: NEW_TIMEOUT_MUST_BE_HIGHER"
        );
        
        withdrawTimeout = newWithdrawTimeout; 
        
        emit NewWithdrawTimeout(newWithdrawTimeout);
    }

    /**
     * @notice Function to extract the selector of a bytes calldata
     * @param _data The calldata bytes
     */
    function _getSelector(bytes memory _data) private pure returns (bytes4 sig) {
        assembly {
            sig := mload(add(_data, 32))
        }
    }

    /**
     * @notice Function to call token permit method of extended ERC20
     + @param token ERC20 token address
     * @param _amount Quantity that is expected to be allowed
     * @param _permitData Raw data of the call `permit` of the token
     */
    function _permit(
        address token,
        uint256 _amount,
        bytes calldata _permitData
    ) internal {
        bytes4 sig = _getSelector(_permitData);
        require(
            sig == _PERMIT_SIGNATURE,
            "HezMaticMerge::_permit: NOT_VALID_CALL"
        );
        (
            address owner,
            address spender,
            uint256 value,
            uint256 deadline,
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = abi.decode(
            _permitData[4:],
            (address, address, uint256, uint256, uint8, bytes32, bytes32)
        );
        require(
            owner == msg.sender,
            "HezMaticMerge::_permit: PERMIT_OWNER_MUST_BE_THE_SENDER"
        );
        require(
            spender == address(this),
            "HezMaticMerge::_permit: SPENDER_MUST_BE_THIS"
        );
        require(
            value == _amount,
            "HezMaticMerge::_permit: PERMIT_AMOUNT_DOES_NOT_MATCH"
        );

        // we call without checking the result, in case it fails and he doesn't have enough balance
        // the following transferFrom should be fail. This prevents DoS attacks from using a signature
        // before the smartcontract call
        /* solhint-disable avoid-low-level-calls */
        address(token).call(
            abi.encodeWithSelector(
                _PERMIT_SIGNATURE,
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        );
    }   
}
