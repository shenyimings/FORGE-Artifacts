// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '../libraries/RegistryUser.sol';
import '../interfaces/IDistributor.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
 * Duelist King Merchant
 * Name: DuelistKingMerchant
 * Doamin: Duelist King
 */
contract DuelistKingMerchant is RegistryUser {
  using SafeERC20 for ERC20;

  // Sale campaign
  struct SaleCampaign {
    uint256 phaseId;
    uint256 totalSale;
    uint256 basePrice;
    uint256 deadline;
  }

  // Stable coin info
  struct Stablecoin {
    address tokenAddress;
    uint256 decimals;
  }

  // Discount are in 1/10^6, e.g: 100,000 = 10%
  // = 100,000/10^6 = 0.1 * 100% = 10%
  mapping(bytes32 => uint256) private _discount;

  // Maping sale campaign
  mapping(uint256 => SaleCampaign) private _campaign;

  // Stablecoin information
  mapping(address => Stablecoin) private _stablecoin;

  // Total campaign
  uint256 private _totalCampaign;

  // New campaign
  event NewCampaign(uint256 indexed phaseId, uint256 indexed totalSale, uint256 indexed basePrice);

  // A user buy card from merchant
  event Purchase(address indexed owner, uint256 indexed phaseId, uint256 indexed numberOfBoxes);

  // Update supporting stablecoin
  event UpdateStablecoin(address indexed contractAddress, uint256 indexed decimals, bool isListed);

  // Constructor method
  constructor(address registry_, bytes32 domain_) {
    _registryUserInit(registry_, domain_);
  }

  /*******************************************************
   * Sales Agent section
   ********************************************************/

  // Create a new campaign
  function createNewCampaign(SaleCampaign memory newCampaign)
    external
    onlyAllowSameDomain('Sales Agent')
    returns (uint256)
  {
    IDistributor distributor = IDistributor(_getAddressSameDomain('Distributor'));
    require(
      distributor.getRemainingBox(newCampaign.phaseId) > newCampaign.totalSale,
      'Merchant: Invalid number of selling boxes'
    );
    // We use 10^6 or 6 decimal for fiat value, e.g $4.8 -> 4,800,000
    require(newCampaign.basePrice > 1000000, 'Merchant: Base price must greater than 1 unit');
    require(newCampaign.deadline > block.timestamp, 'Merchant: Deadline must be in the future');
    uint256 currentCampaignId = _totalCampaign;
    _campaign[currentCampaignId] = newCampaign;
    _totalCampaign += 1;
    emit NewCampaign(newCampaign.phaseId, newCampaign.totalSale, newCampaign.basePrice);
    return currentCampaignId;
  }

  // Create a new supported stable coin
  function manageStablecoin(
    address tokenAddress,
    uint256 decimals,
    bool isListing
  ) external onlyAllowSameDomain('Sales Agent') returns (bool) {
    if (decimals == 0) {
      decimals = ERC20(tokenAddress).decimals();
    }
    _stablecoin[tokenAddress] = Stablecoin({ tokenAddress: tokenAddress, decimals: decimals });
    emit UpdateStablecoin(tokenAddress, decimals, isListing);
    return true;
  }

  /*******************************************************
   * Public section
   ********************************************************/

  // Anyone could buy NFT from smart contract
  function buy(
    uint256 campaignId,
    uint256 numberOfBoxes,
    address tokenAddress,
    bytes32 code
  ) external returns (bool) {
    require(isSupportedStablecoin(tokenAddress), 'Merchant: Stablecoin was not supported');
    IDistributor distributor = IDistributor(_getAddressSameDomain('Distributor'));
    SaleCampaign memory currentCampaign = _campaign[campaignId];
    require(block.timestamp < currentCampaign.deadline, 'Merchant: Sale campaign was ended');
    uint256 priceInToken = tokenAmountAfterDiscount(
      currentCampaign.basePrice,
      code,
      _stablecoin[tokenAddress].decimals
    );
    // Calcualate box price

    // Verify payment
    _tokenTransfer(tokenAddress, msg.sender, address(this), priceInToken * numberOfBoxes);
    distributor.mintBoxes(msg.sender, numberOfBoxes, currentCampaign.phaseId);
    emit Purchase(msg.sender, currentCampaign.phaseId, numberOfBoxes);
    return true;
  }

  /*******************************************************
   * Private section
   ********************************************************/

  // Transfer token to receiver
  function _tokenTransfer(
    address tokenAddress,
    address sender,
    address receiver,
    uint256 amount
  ) private returns (bool) {
    ERC20 token = ERC20(tokenAddress);
    uint256 beforeBalance = token.balanceOf(receiver);
    token.safeTransferFrom(sender, receiver, amount);
    uint256 afterBalance = token.balanceOf(receiver);
    require(afterBalance - beforeBalance == amount, 'Merchant: Invalid token transfer');
    return true;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Check a stablecoin is supported or not
  function isSupportedStablecoin(address tokenAddress) public view returns (bool) {
    return _stablecoin[tokenAddress].tokenAddress == tokenAddress;
  }

  // Calculate price after apply discount code
  // discountedPrice = basePrice - (basePrice * discount)/10^6
  // tokenPrice = discountedPrice * 10^decimals
  function tokenAmountAfterDiscount(
    uint256 basePrice,
    bytes32 code,
    uint256 decmials
  ) public view returns (uint256) {
    return ((basePrice - ((basePrice * _discount[code]) / 1000000)) * 10**decmials) / 1000000;
  }

  // Get total campaign
  function getTotalCampaign() external view returns (uint256) {
    return _totalCampaign;
  }

  // Get campaign detail
  function getCampaignDetail(uint256 campaignId) external view returns (SaleCampaign memory) {
    return _campaign[campaignId];
  }
}
