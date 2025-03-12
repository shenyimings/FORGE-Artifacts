// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "./utils/Owned.sol";
import "./interfaces/ISupplySchedule.sol";

// Libraries
import "./libraries/SafeDecimalMath.sol";
import "./libraries/Math.sol";

// Internal references
import "./interfaces/IERC20.sol";
import "./interfaces/IKwenta.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/IMultipleMerkleDistributor.sol";

// https://docs.synthetix.io/contracts/source/contracts/supplyschedule
contract SupplySchedule is Owned, ISupplySchedule {
    using SafeDecimalMath for uint;
    using Math for uint;

    IKwenta public kwenta;
    IStakingRewards public stakingRewards;
    IMultipleMerkleDistributor public tradingRewards;

    // Time of the last inflation supply mint event
    uint public lastMintEvent;

    // Counter for number of weeks since the start of supply inflation
    uint public weekCounter;

    // The number of KWENTA rewarded to the caller of Kwenta.mint()
    uint public minterReward = 1e18;

    uint public constant INITIAL_SUPPLY = 313373e18;

    // Initial Supply * 240% Initial Inflation Rate / 52 weeks.
    uint public constant INITIAL_WEEKLY_SUPPLY = INITIAL_SUPPLY * 240 / 100 / 52;

    // Max KWENTA rewards for minter
    uint public constant MAX_MINTER_REWARD = 20 * 1e18;

    // How long each inflation period is before mint can be called
    uint public constant MINT_PERIOD_DURATION = 1 weeks;

    uint public immutable inflationStartDate;
    uint public constant MINT_BUFFER = 1 days;
    uint8 public constant SUPPLY_DECAY_START = 2; // Supply decay starts on the 2nd week of rewards
    uint8 public constant SUPPLY_DECAY_END = 208; // Inclusive of SUPPLY_DECAY_END week.

    // Weekly percentage decay of inflationary supply
    uint public constant DECAY_RATE = 20500000000000000; // 2.05% weekly

    // Percentage growth of terminal supply per annum
    uint public constant TERMINAL_SUPPLY_RATE_ANNUAL = 10000000000000000; // 1.0% pa

    uint public treasuryDiversion = 2000; // 20% to treasury
    uint public tradingRewardsDiversion = 2000;

    // notice treasury address may change
    address public treasuryDAO;

    /* ========== EVENTS ========== */
    
    /**
     * @notice Emitted when the inflationary supply is minted
     **/
    event SupplyMinted(uint supplyMinted, uint numberOfWeeksIssued, uint lastMintEvent);

    /**
     * @notice Emitted when the KWENTA minter reward amount is updated
     **/
    event MinterRewardUpdated(uint newRewardAmount);

    /**
     * @notice Emitted when setKwenta is called changing the Kwenta Proxy address
     **/
    event KwentaUpdated(address newAddress);

    /**
     * @notice Emitted when treasury inflation share is changed
     **/
    event TreasuryDiversionUpdated(uint newPercentage);

    /**
     * @notice Emitted when trading rewards inflation share is changed
     **/
    event TradingRewardsDiversionUpdated(uint newPercentage);

    /**
     * @notice Emitted when StakingRewards is changed
     **/
    event StakingRewardsUpdated(address newAddress);

    /**
     * @notice Emitted when TradingRewards is changed
     **/
    event TradingRewardsUpdated(address newAddress);

    /**
     * @notice Emitted when treasuryDAO address is changed
     **/
    event TreasuryDAOSet(address treasuryDAO);

    constructor(
        address _owner,
        address _treasuryDAO
    ) Owned(_owner) {
        treasuryDAO = _treasuryDAO;

        inflationStartDate = block.timestamp; // inflation starts as soon as the contract is deployed.
        lastMintEvent = block.timestamp;
        weekCounter = 0;
    }

    // ========== VIEWS ==========

    /**
     * @return The amount of KWENTA mintable for the inflationary supply
     */
    function mintableSupply() override public view returns (uint) {
        uint totalAmount;

        if (!isMintable()) {
            return totalAmount;
        }

        uint remainingWeeksToMint = weeksSinceLastIssuance();

        uint currentWeek = weekCounter;

        // Calculate total mintable supply from exponential decay function
        // The decay function stops after week 208
        while (remainingWeeksToMint > 0) {
            currentWeek++;

            if (currentWeek < SUPPLY_DECAY_START) {
                // If current week is before supply decay we add initial supply to mintableSupply
                totalAmount = totalAmount + INITIAL_WEEKLY_SUPPLY;
                remainingWeeksToMint--;
            } else if (currentWeek <= SUPPLY_DECAY_END) {
                // if current week before supply decay ends we add the new supply for the week
                // diff between current week and (supply decay start week - 1)
                uint decayCount = currentWeek - (SUPPLY_DECAY_START - 1);

                totalAmount = totalAmount + tokenDecaySupplyForWeek(decayCount);
                remainingWeeksToMint--;
            } else {
                // Terminal supply is calculated on the total supply of Kwenta including any new supply
                // We can compound the remaining week's supply at the fixed terminal rate
                uint totalSupply = IERC20(kwenta).totalSupply();
                uint currentTotalSupply = totalSupply + totalAmount;

                totalAmount = totalAmount + terminalInflationSupply(currentTotalSupply, remainingWeeksToMint);
                remainingWeeksToMint = 0;
            }
        }

        return totalAmount;
    }

    /**
     * @return A unit amount of decaying inflationary supply from the INITIAL_WEEKLY_SUPPLY
     * @dev New token supply reduces by the decay rate each week calculated as supply = INITIAL_WEEKLY_SUPPLY * ()
     */
    function tokenDecaySupplyForWeek(uint counter) public pure returns (uint) {
        // Apply exponential decay function to number of weeks since
        // start of inflation smoothing to calculate diminishing supply for the week.
        uint effectiveDecay = (SafeDecimalMath.unit() - DECAY_RATE).powDecimal(counter);
        uint supplyForWeek = INITIAL_WEEKLY_SUPPLY.multiplyDecimal(effectiveDecay);

        return supplyForWeek;
    }

    /**
     * @return A unit amount of terminal inflation supply
     * @dev Weekly compound rate based on number of weeks
     */
    function terminalInflationSupply(uint totalSupply, uint numOfWeeks) public pure returns (uint) {
        // rate = (1 + weekly rate) ^ num of weeks
        uint effectiveCompoundRate = (SafeDecimalMath.unit() + (TERMINAL_SUPPLY_RATE_ANNUAL / 52)).powDecimal(numOfWeeks);

        // return Supply * (effectiveRate - 1) for extra supply to issue based on number of weeks
        return totalSupply.multiplyDecimal(effectiveCompoundRate - SafeDecimalMath.unit());
    }

    /**
     * @dev Take timeDiff in seconds (Dividend) and MINT_PERIOD_DURATION as (Divisor)
     * @return Calculate the numberOfWeeks since last mint rounded down to 1 week
     */
    function weeksSinceLastIssuance() public view returns (uint) {
        // Get weeks since lastMintEvent
        // If lastMintEvent not set or 0, then start from inflation start date.
        uint timeDiff = block.timestamp - lastMintEvent;
        return timeDiff / MINT_PERIOD_DURATION;
    }

    /**
     * @return boolean whether the MINT_PERIOD_DURATION (7 days)
     * has passed since the lastMintEvent.
     * */
    function isMintable() override public view returns (bool) {
        return block.timestamp - lastMintEvent > MINT_PERIOD_DURATION;
    }

    // ========== MUTATIVE FUNCTIONS ==========

    /**
     * @notice Record the mint event from Kwenta by incrementing the inflation
     * week counter for the number of weeks minted (probabaly always 1)
     * and store the time of the event.
     * @param supplyMinted the amount of KWENTA the total supply was inflated by.
     * */
    function recordMintEvent(uint supplyMinted) internal returns (bool) {
        uint numberOfWeeksIssued = weeksSinceLastIssuance();

        // add number of weeks minted to weekCounter
        weekCounter = weekCounter + numberOfWeeksIssued;

        // Update mint event to latest week issued (start date + number of weeks issued * seconds in week)
        // 1 day time buffer is added so inflation is minted after feePeriod closes
        lastMintEvent = inflationStartDate + (weekCounter * MINT_PERIOD_DURATION) + MINT_BUFFER;

        emit SupplyMinted(supplyMinted, numberOfWeeksIssued, lastMintEvent);
        return true;
    }

    /**
     * @notice Mints new inflationary supply weekly
     * New KWENTA is distributed between the minter, treasury, and StakingRewards contract
     * */
    function mint() override external {
        require(address(stakingRewards) != address(0), "Staking rewards not set");
        require(address(tradingRewards) != address(0), "Trading rewards not set");

        uint supplyToMint = mintableSupply();
        require(supplyToMint > 0, "No supply is mintable");

        // record minting event before mutation to token supply
        recordMintEvent(supplyToMint);

        uint amountToDistribute = supplyToMint - minterReward;
        uint amountToTreasury = amountToDistribute * treasuryDiversion / 10000;
        uint amountToTradingRewards = amountToDistribute * tradingRewardsDiversion / 10000;
        uint amountToStakingRewards = amountToDistribute - amountToTreasury - amountToTradingRewards;

        kwenta.mint(treasuryDAO, amountToTreasury);
        kwenta.mint(address(tradingRewards), amountToTradingRewards);
        kwenta.mint(address(stakingRewards), amountToStakingRewards);
        stakingRewards.notifyRewardAmount(amountToStakingRewards);
        kwenta.mint(msg.sender, minterReward);
    }

    // ========== SETTERS ========== */

    /**
     * @notice Set the Kwenta should it ever change.
     * SupplySchedule requires Kwenta address as it has the authority
     * to record mint event.
     * */
    function setKwenta(IKwenta _kwenta) external onlyOwner {
        require(address(_kwenta) != address(0), "Address cannot be 0");
        kwenta = _kwenta;
        emit KwentaUpdated(address(kwenta));
    }

    /**
     * @notice Sets the reward amount of KWENTA for the caller of the public
     * function Kwenta.mint().
     * This incentivises anyone to mint the inflationary supply and the mintr
     * Reward will be deducted from the inflationary supply and sent to the caller.
     * @param amount the amount of KWENTA to reward the minter.
     * */
    function setMinterReward(uint amount) external onlyOwner {
        require(amount <= MAX_MINTER_REWARD, "SupplySchedule: Reward cannot exceed max minter reward");
        minterReward = amount;
        emit MinterRewardUpdated(minterReward);
    }

    function setTreasuryDiversion(uint _treasuryDiversion) override external onlyOwner {
        require(_treasuryDiversion + tradingRewardsDiversion < 10000, "SupplySchedule: Cannot be more than 100%");
        treasuryDiversion = _treasuryDiversion;
        emit TreasuryDiversionUpdated(_treasuryDiversion);
    }

    function setTradingRewardsDiversion(uint _tradingRewardsDiversion) override external onlyOwner {
        require(_tradingRewardsDiversion + treasuryDiversion < 10000, "SupplySchedule: Cannot be more than 100%");
        tradingRewardsDiversion = _tradingRewardsDiversion;
        emit TradingRewardsDiversionUpdated(_tradingRewardsDiversion);
    }

    function setStakingRewards(address _stakingRewards) override external onlyOwner {
        require(_stakingRewards != address(0), "SupplySchedule: Invalid Address");
        stakingRewards = IStakingRewards(_stakingRewards);
        emit StakingRewardsUpdated(_stakingRewards);
    }

    function setTradingRewards(address _tradingRewards) override external onlyOwner {
        require(_tradingRewards != address(0), "SupplySchedule: Invalid Address");
        tradingRewards = IMultipleMerkleDistributor(_tradingRewards);
        emit TradingRewardsUpdated(_tradingRewards);
    }

    /// @notice set treasuryDAO address
    /// @dev only owner may change address
    function setTreasuryDAO(address _treasuryDAO) external onlyOwner {
        require(_treasuryDAO != address(0), "SupplySchedule: Zero Address");
        treasuryDAO = _treasuryDAO;
        emit TreasuryDAOSet(treasuryDAO);
    }
}