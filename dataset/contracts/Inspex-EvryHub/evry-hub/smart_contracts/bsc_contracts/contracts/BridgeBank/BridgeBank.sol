// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./BscBank.sol";
import "./BridgeBankPausable.sol";
import "./Ownable.sol";
import "../../node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./Validator.sol";
/**
 * @title BridgeBank
 * @dev Bank contract which coordinates asset-related functionality.
 *      BscBank manages the locking and unlocking of BNB/BEP20 token assets
 *      based on Bsc.
 **/

contract BridgeBank is Initializable, BscBank, BridgeBankPausable, Ownable, Validator, ReentrancyGuardUpgradeable{
    using SafeERC20 for BridgeToken;

    address public operator;
    address public timeLockContract;
    /*
     * @dev: Constructor, sets operator
     */
    function initialize(address _operatorAddress, address _timeLockAddress, address _validator) public payable initializer {
        operator = _operatorAddress;
        timeLockContract = _timeLockAddress;
        addValidator(_validator);
        owner = payable(msg.sender);
        lockBurnNonce = 0;
        _paused = false;
        __ReentrancyGuard_init();
    }

    /*
     * @dev: Modifier to restrict access to operator
     */
    modifier onlyOperator() {
        require(msg.sender == operator, "Must be BridgeBank operator.");
        _;
    }

    /*
    * @dev: Modifier to restrict state change to timeLock smart contract
    */
    modifier isTimeLock() {
        require(msg.sender == timeLockContract, "Must be timeLock smart contract");
        _;
    }

    /*
     * @dev: Change to new Operator
     *
     */
    event LogChangeOperator(address _oldOperator, address _newOperator);
    
    function changeOperator(address _newOperator)
        public
        isTimeLock
    {
        require(_newOperator != address(0), "Operator equals null address");

        emit LogChangeOperator(operator, _newOperator);

        operator = _newOperator;
    }

    /*
     * @dev: Add validator
     *
     */
    function addValidator(address _newValidator)
        public
        isTimeLock
    {   
        _addValidator(_newValidator);
    }

        

    /*
     * @dev: Fallback/receive function allows anyone to send funds to the bank directly
     *
     */

    fallback() external payable {}
    receive() external payable {}
    
    /**
     * @dev Pauses all functions.
     * Set timestamp for current pause
     */
    function pause() public isTimeLock{
        _pause();
    }

    /**
     * @dev Unpauses all functions.
     * No need to reset pausedAt when pausing it will automatically increase
     */
    function unpause() public isTimeLock {
        _unpause();
    }

    /*
     * @dev: Locks received BNB/BEP20 funds.
     *
     * @param _recipient: representation of destination address.
     * @param _token: token address in origin chain (0x0 if ethereum)
     * @param _amount: value of deposit
     */
    function lock(
        address _recipient,
        address _token,
        uint256 _amount,
        string memory _chainName
    ) public payable whenNotPaused nonReentrant{
        string memory symbol;

        // BNB deposit
        if (msg.value > 0) {
            require(
                _token == address(0),
                "BNB requires null address"
            );
            require(
                msg.value == _amount,
                "Msg.value != _amount"
            );
            symbol = "BNB";

            lockFunds(
            payable(msg.sender),
            _recipient,
            _token,
            symbol,
            _amount,
            _chainName
            );

        }// BEP20 deposit
        else {
            
            uint beforeLock = BridgeToken(_token).balanceOf(address(this));

            BridgeToken(_token).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );

            uint afterLock = BridgeToken(_token).balanceOf(address(this));

            // Set symbol to the BEP20 token's symbol
            symbol = BridgeToken(_token).symbol();

            lockFunds(
            payable(msg.sender),
            _recipient,
            _token,
            symbol,
            afterLock - beforeLock,
            _chainName
            );
        }
    }

    /*
     * @dev: Unlocks BNB and BEP20 tokens held on the contract.
     *
     * @param _recipient: recipient's is an bsc address
     * @param _token: token contract address
     * @param _symbol: token symbol
     * @param _amount: wei amount or BEP20 token count
     * 
     * This functions is use for unlock IBC assets
     * - Operator send the 
     */
    function unlock(
        uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS, 
        address payable _recipient,
        address tokenAddress,
        string memory _symbol,
        uint256 _amount,
        uint256 _fee,
        bytes32 _interchainTX
    ) public onlyOperator
             whenNotPaused
             nonReentrant
             validatorPrecheck(sigV, sigR, sigS)
    {
        require(_amount > _fee, "Input amount <= fee");
        require(
            sigV.length == sigR.length && sigR.length == sigS.length && sigV.length > 0
        );

        require(
            _checkUnlockSig(sigV, sigR, sigS, _recipient, tokenAddress, _symbol, _amount, _interchainTX), 
            "Invalid signature"
        );

        require(
            unlockCompleted[_interchainTX].isUnlocked == false,
            "Processed before"
        );

        // Check if it is EVRY
        if (tokenAddress == address(0)) {
            address thisadd = address(this);
            require(
                thisadd.balance >= _amount,
                "Insufficient balance."
            );
        } else {
            require(
                BridgeToken(tokenAddress).balanceOf(address(this)) >= _amount,
                "Insufficient ERC20 balance."
            );
        }

        unlockFunds(_recipient, owner, tokenAddress, _symbol, _amount, _fee, _interchainTX);
    }

    function emergencyWithdraw(uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS, address tokenAddress, uint256 _amount)
        public
        onlyOperator 
        whenPaused
        nonReentrant
        validatorPrecheck(sigV, sigR, sigS)
    {
        require(
            sigV.length == sigR.length && sigR.length == sigS.length && sigV.length > 0
        );

        require(
            _checkEmergencySig(sigV, sigR, sigS, tokenAddress, _amount), 
            "Invalid signature"
        );
        // Check if it is BNB
        if (tokenAddress == address(0)) {
            address thisadd = address(this);
            require(
                thisadd.balance >= _amount,
                "Insufficient balance."
            );
            payable(msg.sender).transfer(_amount);
        } else {
            require(
                BridgeToken(tokenAddress).balanceOf(address(this)) >= _amount,
                "Insufficient ERC20 balance."
            );
            BridgeToken(tokenAddress).safeTransfer(owner, _amount);
        }
    }

    /*
     * @dev: Refund BNB and BEP20 tokens held on the contract.
     *
     * @param _recipient: recipient's is an bsc address
     * @param _token: token contract address
     * @param _symbol: token symbol
     * @param _amount: wei amount or BEP20 token count
     */
    function refund(
        uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS,
        address payable _recipient,
        address _tokenAddress,
        string memory _symbol,
        uint256 _amount,
        uint256 _nonce
    ) public onlyOperator whenNotPaused nonReentrant validatorPrecheck(sigV, sigR, sigS)
     {
        require(
            sigV.length == sigR.length && sigR.length == sigS.length && sigV.length > 0
        );

        require(
            _checkRefundSig(sigV, sigR, sigS, _recipient, _tokenAddress, _symbol, _amount, _nonce), 
            "Invalid signature"
        );
        require(
            refundCompleted[_nonce].isRefunded == false,
            "Processed before"
        );
        require(
            refundCompleted[_nonce].tokenAddress == _tokenAddress,
            "Invalid tokenAdress"
        );
        require(
            refundCompleted[_nonce].sender == _recipient,
            "Invalid recipient"
        );
        require(
            refundCompleted[_nonce].amount == _amount,
            "Invalid amount"
        );
        // Check if it is BNB
        if (_tokenAddress == address(0)) {
            address thisadd = address(this);
            require(
                thisadd.balance >= _amount,
                "Insufficient ethereum balance for delivery."
            );
        } else {
            require(
                BridgeToken(_tokenAddress).balanceOf(address(this)) >= _amount,
                "Insufficient ERC20 token balance for delivery."
            );
        }
        refunds(_recipient, _tokenAddress, _symbol, _amount, _nonce);
    }

    /*
     * @dev: For validators to get the lock data in order to verify 
     *       if it is correct data that they need to verify with signature
     *
     * @param _recipient: Nonce Number
     * @return lockData
     */
    function getLockData(uint256 _nonce) public view returns (bool, uint256, address, address, uint256, string memory){
        return _getLockData(_nonce);
    }
    
    // This function check the mapping to see if the transaction  is unlockeds
    function checkIsUnlocked(bytes32 _interchainTX) public view returns (bool) {
        return unlockCompleted[_interchainTX].isUnlocked;
    }

    function checkIsRefunded(uint256 _id) public view returns (bool) {
        return refundCompleted[_id].isRefunded;
    }
}
