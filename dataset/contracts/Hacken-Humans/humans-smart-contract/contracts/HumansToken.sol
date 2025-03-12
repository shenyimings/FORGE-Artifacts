// SPDX-License-Identifier: Humans Token AG
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./lib/Author.sol";
import "./lib/UnlockSchedule.sol";
import "./lib/Wallets.sol";

contract HumansToken is Initializable, ERC20Upgradeable, ERC20SnapshotUpgradeable, OwnableUpgradeable, PausableUpgradeable, Author, UnlockSchedule {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __ERC20_init("HUMANS", "HEART");
    __ERC20Snapshot_init();
    __Ownable_init();
    __Pausable_init();
  }

  function snapshot() external onlyOwner {
    _snapshot();
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20Upgradeable, ERC20SnapshotUpgradeable) whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }

  function TriggerTokenGenerationEvent() external onlyOwner {
    require(!_tgeInitialized, "Humans Token: Token Generation Event already triggered!");
    _initialize_tged();
  }

  // Public Sale Unlock functions
  function PublicSale_TGE_Unlock() external onlyOwner returns (uint256 amount) {
    require(PUBLIC_SALE_SCHEDULE[0].Claimed == false, "Unlock Schedule: The token generation event amount for the public sale wallet has already been claimed!");
    amount = PUBLIC_SALE_SCHEDULE[0].Amount;
    emit ScheduleUnlock("Public Sale Schedule - token generation event", PUBLIC_SALE_SCHEDULE[0].Amount, 0, block.timestamp);
    _mint(Wallets.PUBLIC_SALE_WALLET, amount);
  }

  function TriggerPublicSaleScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _publicSale_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the public sale wallet schedule!");
    _mint(Wallets.PUBLIC_SALE_WALLET, amount);
  }

  // Comunity Incentives & Rewards Unlock functions
  function TriggerComunityIncentivesAndRewardsScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _comunity_incentives_and_rewards_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the comunity incentives and rewards wallet schedule!");
    _mint(Wallets.COMUNITY_INCENTIVES_AND_REWARDS_WALLET, amount);
  }

  // Private Sale functions
  function TriggerPrivateSaleScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _privateSale_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the private sale wallet schedule!");
    _mint(Wallets.PRIVATE_SALE_WALLET, amount);
  }

  // Team functions
  function TriggerTeamScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _team_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the team wallet schedule!");
    _mint(Wallets.TEAM_WALLET, amount);
  }

  // Marketing functions
  function Marketing_TGE_Unlock() external onlyOwner returns (uint256 amount) {
    require(!MARKETING_SCHEDULE[0].Claimed, "Unlock Schedule: The token generation event amount for the marketing wallet has already been claimed!");
    amount = MARKETING_SCHEDULE[0].Amount;
    emit ScheduleUnlock("Marketing Schedule - token generation event", MARKETING_SCHEDULE[0].Amount, 0, block.timestamp);
    _mint(Wallets.MARKETING_WALLET, amount);
  }

  function TriggerMarketingScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _marketing_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the marketing wallet schedule!");
    _mint(Wallets.MARKETING_WALLET, amount);
  }

  // Advisors and Strategic partners functions
  function TriggerAdvisorsAndStrategicPartnersScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _advisors_and_strategic_partners_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the marketing wallet schedule!");
    _mint(Wallets.ADVISORS_AND_STRATEGIC_PARTNERS_WALLET, amount);
  }

  // Strategic OTC functions
  function TriggerStrategicOTCScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _strategic_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the strategic otc wallet schedule!");
    _mint(Wallets.STRATEGIC_OTC_WALLET, amount);
  }

  // LiquidityExchangeAndListings functions
  function LiquidityExchangeAndListings_TGE_Unlock() external onlyOwner returns (uint256 amount) {
    require(!LIQUIDITY_AND_EXCHANGE_LISTINGS_SCHEDULE[0].Claimed, "Unlock Schedule: The token generation event amount for the liquidity exchange and listings wallet has already been claimed!");
    amount = LIQUIDITY_AND_EXCHANGE_LISTINGS_SCHEDULE[0].Amount;
    emit ScheduleUnlock("Liquidity and Exchange Listings Schedule - token generation event", LIQUIDITY_AND_EXCHANGE_LISTINGS_SCHEDULE[0].Amount, 0, block.timestamp);
    _mint(Wallets.LIQUIDITY_AND_EXCHANGE_LISTING_WALLET, amount);
  }

  function TriggerLiquidityExchangeAndListingScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _liquidity_and_exchange_listings_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the liquidity exchange and listings wallet schedule!");
    _mint(Wallets.LIQUIDITY_AND_EXCHANGE_LISTING_WALLET, amount);
  }

  // Sustainable Development functions
  function SustainableDevelopment_TGE_Unlock() external onlyOwner returns (uint256 amount) {
    require(!SUSTAINABLE_DEVELOPMENT_SCHEDULE[0].Claimed, "Unlock Schedule: The token generation event amount for the sustainable development schedule wallet has already been claimed!");
    amount = SUSTAINABLE_DEVELOPMENT_SCHEDULE[0].Amount;
    emit ScheduleUnlock("Sustainable Schedule - token generation event", SUSTAINABLE_DEVELOPMENT_SCHEDULE[0].Amount, 0, block.timestamp);
    _mint(Wallets.SUSTAINABLE_DEVELOPMENT_WALLET, amount);
  }

  function TriggerSustainableDevelopmentScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _sustainable_development_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the sustainable development wallet schedule!");
    _mint(Wallets.SUSTAINABLE_DEVELOPMENT_WALLET, amount);
  }

  // Business Development functions
  function BusinessDevelopment_TGE_Unlock() external onlyOwner returns (uint256 amount) {
    require(!BUSINESS_DEVELOPMENT_SCHEDULE[0].Claimed, "Unlock Schedule: The token generation event amount for the business development wallet has already been claimed!");
    amount = BUSINESS_DEVELOPMENT_SCHEDULE[0].Amount;
    emit ScheduleUnlock("Sustainable Schedule - token generation event", BUSINESS_DEVELOPMENT_SCHEDULE[0].Amount, 0, block.timestamp);
    _mint(Wallets.BUSINESS_DEVELOPMENT_WALLET, amount);
  }

  function TriggerBusinessDevelopmentScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _business_development_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the business development wallet schedule!");
    _mint(Wallets.BUSINESS_DEVELOPMENT_WALLET, amount);
  }

  // Sustainable Development functions
  function AiMiningAndStaking_TGE_Unlock() external onlyOwner returns (uint256 amount) {
    require(AI_MINING_AND_STAKING_REWARDS_SCHEDULE[0].Claimed == false, "Unlock Schedule: The token generation event amount for the business development wallet has already been claimed!");
    amount = AI_MINING_AND_STAKING_REWARDS_SCHEDULE[0].Amount;
    emit ScheduleUnlock("Sustainable Schedule - token generation event", AI_MINING_AND_STAKING_REWARDS_SCHEDULE[0].Amount, 0, block.timestamp);
    _mint(Wallets.AI_MINING_AND_STAKING_REWARDS_WALLET, amount);
  }

  function TriggerAIMiningAndStakingScheduledUnlock() external onlyOwner {
    require(_tgeInitialized, "Humans Token: Token Generation Event was not triggered!");
    uint256 amount = _ai_mining_and_staking_scheduled_unlock();
    require(amount > 0, "Humans Token: nothing to unlock from the business development wallet schedule!");
    _mint(Wallets.AI_MINING_AND_STAKING_REWARDS_WALLET, amount);
  }
}
