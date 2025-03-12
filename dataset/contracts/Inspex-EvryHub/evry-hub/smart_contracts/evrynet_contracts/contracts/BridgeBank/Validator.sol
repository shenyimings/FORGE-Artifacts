// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title Validator
 * @dev To handle the multisig
 * Author: luc.vu
 * Company: sotatek.com
 **/

contract Validator{

    address[] private validators;
    // Fixed threshold to validate unlock/refund/emergency withdraw equal or more than 2/3 signatures
    uint private constant threshold = 66;
    
    function getValidators() public view returns (address[] memory){
        return  validators;
    }

    event LogAddValidator(address _validator);

    function _addValidator(address _validator) internal {
        require(_validator != address(0), "Null address");
        for(uint index = 0; index < validators.length; index++){
            require(_validator != validators[index], "Already added");
        }
        validators.push(_validator);

        emit LogAddValidator(_validator);
    }

    event LogRemoveValidator(address _validator);

    function _removeValidator(address _validator) internal {
        require(_validator != address(0), "Null address");
        require(validators.length > 0, "Validators = 0");
        for(uint index = 0; index < validators.length; index++){
            if(_validator == validators[index]){
                validators[index] = validators[validators.length - 1];
                validators.pop();
                emit LogRemoveValidator(_validator);
                return;
            }
        }
        require(false, "Could not find validator to remove");
    }
    
    event LogUpdateValidator(address _oldValidator, address _newValidator);

    function _updateValidator(address _old, address _new) private{
        require(_old != address(0) && _new != address(0), "Null address");
        require(validators.length > 0, "Validators.length = 0");
        for(uint index = 0; index < validators.length; index++){
            if(_old == validators[index]){
                validators[index] = _new;
                emit LogUpdateValidator(_old, _new);
                return;
            }
        }
        require(false, "No old validator");
    }

    function _checkSignature(uint8 _sigV,
                             bytes32 _sigR,
                             bytes32 _sigS,
                             bytes32 _inputHash) 
    private view returns (bool)
    {
        address checkAdress = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _inputHash)), _sigV, _sigR, _sigS);
        for(uint index = 0; index < validators.length; index++){
            if(checkAdress == validators[index]){
                return true;
            }
        }
        return  false;
    }

    function _checkUnlockSig(uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS, 
                            address payable _recipient,
                            address tokenAddress,
                            string memory _symbol,
                            uint256 _amount,
                            bytes32 _interchainTX) 
    internal view returns (bool)
    {
            bytes32 funcHash = keccak256("unlock");
            bytes32 symbolHash = keccak256(bytes(_symbol));

            // digest the data to transactionHash
            bytes32 inputHash = keccak256(abi.encode(funcHash, _recipient, tokenAddress, symbolHash, _amount, _interchainTX));
            for(uint index = 0; index < sigV.length; index++){
                // address recoveredAddress = ecrecover(inputHash, sigV[index], sigR[index], sigS[index]);
                if(!_checkSignature(sigV[index], sigR[index], sigS[index], inputHash))
                    return false;
            }
            return true;
    }

    function _checkRefundSig(uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS, 
                            address payable _recipient,
                            address tokenAddress,
                            string memory _symbol,
                            uint256 _amount,
                            uint256 _nonce) 
    internal view returns (bool)
    {
        bytes32 funcHash = keccak256("refund");
        bytes32 symbolHash = keccak256(bytes(_symbol));

        // digest the data to transactionHash
        bytes32 inputHash = keccak256(abi.encode(funcHash, _recipient, tokenAddress, symbolHash, _amount, _nonce));
        for(uint index = 0; index < sigV.length; index++){
            // address recoveredAddress = ecrecover(inputHash, sigV[index], sigR[index], sigS[index]);
            if(!_checkSignature(sigV[index], sigR[index], sigS[index], inputHash))
                return false;
        }
        return true;
    }

    function _checkEmergencySig(uint8[] memory sigV, 
                                bytes32[] memory sigR,
                                bytes32[] memory sigS, 
                                address tokenAddress,
                                uint256 _amount)
    internal view returns (bool)
    {
        bytes32 funcHash = keccak256("emergencyWithdraw");
        // digest the data to transactionHash
        bytes32 inputHash = keccak256(abi.encode(funcHash, tokenAddress, _amount));
        for(uint index = 0; index < sigV.length; index++){
            // address recoveredAddress = ecrecover(inputHash, sigV[index], sigR[index], sigS[index]);
            if(!_checkSignature(sigV[index], sigR[index], sigS[index], inputHash))
                return false;
        }
        return true;
    }


    modifier validatorPrecheck(uint8[] memory _sigV, bytes32[] memory _sigR, bytes32[] memory _sigS){
        require(
            _sigV.length == _sigR.length && _sigR.length == _sigS.length && _sigV.length > 0, 
            "The number of validators must be greater than 0"
        );

        require(
            _sigV.length * 100 / validators.length >= threshold, "The approved validators must be equal or greater than threshold"
        );

        if(_sigV.length >= 2){
            for(uint i = 0; i < _sigV.length; i++){
                for(uint j = i + 1; j < _sigV.length; j++){
                    require(keccak256(abi.encodePacked(_sigV[i], _sigR[i], _sigS[i])) != keccak256(abi.encodePacked(_sigV[j], _sigR[j], _sigS[j])), "Can not be the same signature");
                }   
            }
        }
        _;
    }
}