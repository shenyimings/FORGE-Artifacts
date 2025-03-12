pragma solidity ^0.6.12;

import "./interfaces/SmartFundETHFactoryInterface.sol";
import "./interfaces/SmartFundERC20FactoryInterface.sol";

import "./interfaces/PermittedAddressesInterface.sol";

import "../zeppelin-solidity/contracts/access/Ownable.sol";
import "../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";


/*
* The SmartFundRegistry is used to manage the creation and permissions of SmartFund contracts
*/
contract SmartFundRegistry is Ownable {
  address[] public smartFunds;

  // The Smart Contract which stores the addresses of all the authorized address
  PermittedAddressesInterface public permittedAddresses;

  // Addresses of portals
  address public exchangePortalAddress;

  // Default maximum success fee is 3000/30%
  uint256 public maximumSuccessFee = 3000;

  // Factories
  SmartFundETHFactoryInterface public smartFundETHFactory;
  SmartFundERC20FactoryInterface public smartFundERC20Factory;

  address public platformFeeAddress;

  event SmartFundAdded(address indexed smartFundAddress, address indexed owner);

  /**
  * @dev contructor
  *
  * @param _exchangePortalAddress        Address of the initial ExchangePortal contract
  * @param _smartFundETHFactory          Address of smartFund ETH factory
  * @param _smartFundERC20Factory        Address of smartFund USD factory
  * @param _permittedAddresses           Address of permittedAddresses contract
  */
  constructor(
    address _exchangePortalAddress,
    address _smartFundETHFactory,
    address _smartFundERC20Factory,
    address _permittedAddresses
  ) public {
    exchangePortalAddress = _exchangePortalAddress;
    smartFundETHFactory = SmartFundETHFactoryInterface(_smartFundETHFactory);
    smartFundERC20Factory = SmartFundERC20FactoryInterface(_smartFundERC20Factory);
    permittedAddresses = PermittedAddressesInterface(_permittedAddresses);
    platformFeeAddress = address(this);
  }

  /**
  * @dev Creates a new Full SmartFund
  *
  * @param _name                        The name of the new fund
  * @param _successFee                  The fund managers success fee
  * @param _coreAsset                   Fund core asset
  * @param _isRequireTradeVerification  If true fund can buy only tokens,
  *                                     which include in Merkle Three white list
  */
  function createSmartFund(
    string memory _name,
    uint256       _successFee,
    address       _coreAsset,
    bool          _isRequireTradeVerification
  ) public {
    // Require that the funds success fee be less than the maximum allowed amount
    require(_successFee <= maximumSuccessFee, "Too big fee");

    address smartFund;

    // ETH case
    if(_coreAsset == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
      // Create ETH Fund
      smartFund = smartFundETHFactory.createSmartFund(
        msg.sender,
        _name,
        _successFee, // manager and platform fee
        platformFeeAddress,
        exchangePortalAddress,
        address(permittedAddresses),
        _isRequireTradeVerification
      );

    }
    // USD case
    else{
      // Create ERC20 based fund
      smartFund = smartFundERC20Factory.createSmartFund(
        msg.sender,
        _name,
        _successFee, // manager and platform fee
        platformFeeAddress,
        exchangePortalAddress,
        address(permittedAddresses),
        _coreAsset,
        _isRequireTradeVerification
      );
    }

    smartFunds.push(smartFund);
    emit SmartFundAdded(smartFund, msg.sender);
  }

  function totalSmartFunds() public view returns (uint256) {
    return smartFunds.length;
  }

  function getAllSmartFundAddresses() public view returns(address[] memory) {
    address[] memory addresses = new address[](smartFunds.length);

    for (uint i; i < smartFunds.length; i++) {
      addresses[i] = address(smartFunds[i]);
    }

    return addresses;
  }

  /**
  * @dev Owner can set a new default ExchangePortal address
  *
  * @param _newExchangePortalAddress    Address of the new exchange portal to be set
  */
  function setExchangePortalAddress(address _newExchangePortalAddress) external onlyOwner {
    // Require that the new exchange portal is permitted by permittedAddresses
    require(permittedAddresses.permittedAddresses(_newExchangePortalAddress));

    exchangePortalAddress = _newExchangePortalAddress;
  }

  /**
  * @dev Owner can set maximum success fee for all newly created SmartFunds
  *
  * @param _maximumSuccessFee    New maximum success fee
  */
  function setMaximumSuccessFee(uint256 _maximumSuccessFee) external onlyOwner {
    maximumSuccessFee = _maximumSuccessFee;
  }


  /**
  * @dev Owner can set new smartFundETHFactory
  *
  * @param _smartFundETHFactory    address of ETH factory contract
  */
  function setNewSmartFundETHFactory(address _smartFundETHFactory) external onlyOwner {
    smartFundETHFactory = SmartFundETHFactoryInterface(_smartFundETHFactory);
  }


  /**
  * @dev Owner can set new smartFundERC20Factory
  *
  * @param _smartFundERC20Factory    address of ERC20 factory contract
  */
  function setNewSmartFundERC20Factory(address _smartFundERC20Factory) external onlyOwner {
    smartFundERC20Factory = SmartFundERC20FactoryInterface(_smartFundERC20Factory);
  }


  /**
  * @dev Owner can set new platform address for get platform commisiion
  *
  * @param _newPlatformFeeAddress   new commisiion address
  */
  function setNewPlatformFeeAddress(address _newPlatformFeeAddress) external onlyOwner {
    platformFeeAddress = _newPlatformFeeAddress;
  }

  /**
  * @dev Allows withdarw tokens from this contract if someone will accidentally send tokens here
  *
  * @param _tokenAddress    Address of the token to be withdrawn
  */
  function withdrawTokens(address _tokenAddress) external onlyOwner {
    IERC20 token = IERC20(_tokenAddress);
    token.transfer(owner(), token.balanceOf(address(this)));
  }

  /**
  * @dev Allows withdarw ETH from this contract if someone will accidentally send tokens here
  */
  function withdrawEther() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  // Fallback payable function in order to receive ether when fund manager withdraws their cut
  fallback() external payable {}

}
