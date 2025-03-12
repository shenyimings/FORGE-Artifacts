// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address _address) external view returns (uint256);
}

/// @notice faucet contract that allows callers to receive tokens (daily limit on their wallet address)
contract SwanFaucet is OwnableUpgradeable {
    uint256 constant public tokenAmount = 10000000000; //100 token x 10^8
    uint256 constant public waitTime = 24 hours;

    address constant public NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => uint256) nextAccessTime;

    mapping(address => bool) isAdmin;

    function initialize(address _admin) public initializer {
        require(_admin != address(0));
        isAdmin[_admin] = true;
        __Ownable_init();
    }

    function allowedToWithdraw(address _address) public view returns (bool) {
        return block.timestamp >= nextAccessTime[_address];
    }

    modifier onlyAdmin {
        require(isAdmin[msg.sender], "this sender is not an admin");
        _;
    }

    function setAdmin(address _address) public onlyOwner {
        isAdmin[_address] = true;
    }

    function removeAdmin(address _address) public onlyOwner {
        isAdmin[_address] = false;
    }

    receive() external payable {
    }

    fallback() external payable {
    }

    // pass in array of token addresses and the amount array to send, with a receiving address
    /// @notice receive tokens from this address (if there is enough balance in the contract)
    /// @param _tokenAddresses list of token addresses
    /// @param _tokenAmounts list of amounts
    /// @param _address recipient of tokens
    function sendMultiTokens(address[] memory _tokenAddresses, uint[] memory _tokenAmounts, address _address) public onlyAdmin {
        require(allowedToWithdraw(_address), "please wait 24 hours");
        require(_address != address(0));
        
        nextAccessTime[_address] = block.timestamp + waitTime;

        for(uint i=0; i<_tokenAddresses.length; i++) {
            if(_tokenAddresses[i] == NATIVE ){
                if( _tokenAmounts[i] <= address(this).balance){
                    //_address.call{value: _tokenAmounts[i]}("");
                    payable(_address).transfer(_tokenAmounts[i]);
                }
            }
            else if (_tokenAmounts[i] <= ERC20(_tokenAddresses[i]).balanceOf(address(this))) {
                ERC20(_tokenAddresses[i]).transfer(_address, _tokenAmounts[i]);
            }
        }
    }

}