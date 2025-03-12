/*  _____________________________________________________________________________

    GaussVault: Initial Token Distribution and Time Lock Controller


    MIT License. (c) 2021 Gauss Gang Inc. 

    _____________________________________________________________________________
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "../dependencies/utilities/Initializable.sol";
import "../dependencies/utilities/Context.sol";
import "../dependencies/utilities/UUPSUpgradeable.sol";
import "../dependencies/access/Ownable.sol";
import "../dependencies/interfaces/IBEP20.sol";
import "../dependencies/libraries/Address.sol";
import "../dependencies/contracts/TokenLock.sol";
import "../dependencies/contracts/ScheduledTokenLock.sol";



/*  Initial Token Distribution and Time Lock Contract for the Gauss(GANG) token.
        - Acts as the "owner" for each TokenLock and ScheduledTokenLock that it deploys.
        - There is a public function "releaseAvailableTokens()" that can be called to release any available token in all deployed contracts.
        - Allows the "owner" of this contract to add more TokenLocks or ScheduledTokenLocks at a later date (should their be sufficient tokens held by this contract).
*/
contract GaussVault is Initializable, Context, Ownable, UUPSUpgradeable {

    // Dev-Note: Solidity 0.8.0 added built-in support for checked math, therefore the "SafeMath" library is no longer needed.
    using Address for address;

    // Initializes an event that will be called after each VestingLock contract is deployed.
    event VestingCreated(address beneficiary, address lockAddress, uint256 initialAmount);

    // Initializes two arrays that will hold the deployed contracts of both Simple and Scheduled Time Locks.
    TokenLock[] private _simpleVestingContracts;
    ScheduledTokenLock[] private _scheduledVestingContracts;

    // Initializes variables to hold the address "sender" of the tokens to be transferred, as well as the address that the Gauss(GANG) is deployed to.
    address private _senderAddress;
    IBEP20  private _gaussToken;
    bool private _previouslyLocked;
    uint256 private _decimalsAmount;
    

    /*  The initializer sets internal the values of for the Gauss(GANG) token and _senderAddress
            as well as calling the internal functions that create a Vesting Lock contract for each Pool of tokens. */
    function initialize(address gaussGANGAddress) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init(); 
        __GaussVault_init_unchained(gaussGANGAddress);
    }


    /*  The initializer sets internal the values of for the Gauss(GANG) token and _senderAddress
            as well as calling the internal functions that create a Vesting Lock contract for each Pool of tokens. */
    function __GaussVault_init_unchained(address gaussGANGAddress) internal initializer {
        _senderAddress = address(this);
        _gaussToken = IBEP20(gaussGANGAddress);
        _previouslyLocked = false;
        _decimalsAmount = (10 ** _gaussToken.decimals());
    }


    // Receive function to recieve BNB, necessary to cover gas fees.
    receive() external payable {}


    /*  Calls the internal functions that create a Vesting Lock contract for each Pool of tokens.
            NOTE:   - Must be called from "owner".
                    - Owner of GaussGANG Token must transfer the total supply, 250,000,000 tokens, to this contract address before calling function. */
    function lockGaussVault() public onlyOwner() {

        if (_previouslyLocked == false) {
            _lockCommunityTokens();
            _lockLiquidityTokens();
            _lockCharitableFundTokens();
            _lockAdvisorTokens();
            _lockCoreTeamTokens();
            _lockMarketingTokens();
            _lockOpsDevTokens();
            _lockVestingIncentiveTokens();
            _lockReserveTokens();

            _previouslyLocked = true;
        }
    }


    // Returns the beneficiary wallet address of each Vesting Lock, can be called by anyone.
    function beneficiaryVestingAddresses() public view returns (address[] memory) {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);
        address[] memory beneficiaryWallets = new address[](numberOfAddresses);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                beneficiaryWallets[i] = _simpleVestingContracts[i].beneficiary();
            }
            else {
                beneficiaryWallets[i] = _scheduledVestingContracts[(i - _simpleVestingContracts.length)].beneficiary();
            }
        }

        return beneficiaryWallets; 
    }


    // Returns the addresses of each Vesting Contract deployed, can be called by anyone.
    function vestingContractAddresses() public view returns (address[] memory) {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);
        address[] memory contractAddresses = new address[](numberOfAddresses);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                contractAddresses[i] = _simpleVestingContracts[i].contractAddress();
            }
            else {
                contractAddresses[i] = _scheduledVestingContracts[(i - _simpleVestingContracts.length)].contractAddress();
            }
        }

        return contractAddresses; 
    }


    /*  Attempts to release every wallet, ultimately releasing the available amount per Token Lock Contract.
            - Only releases a wallet if the release time for said wallet has passed.                       */
    function releaseAvailableTokens() external onlyOwner() {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                if (block.timestamp >= _simpleVestingContracts[i].releaseTime()) {
                    _simpleVestingContracts[i].release();
                }
            }
            else {
                if (block.timestamp >= _scheduledVestingContracts[(i - _simpleVestingContracts.length)].releaseTime()) {
                    _scheduledVestingContracts[(i - _simpleVestingContracts.length)].release();
                }
            }
        }
    }


    // Returns releaseTimes for each TokenLock Contract.
    function showReleaseTimes() external view returns (address[] memory, uint256[] memory) {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);
        address[] memory beneficiaryWallets = new address[](numberOfAddresses);
        uint256[] memory releaseTimes = new uint256[](numberOfAddresses);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                beneficiaryWallets[i] = _simpleVestingContracts[i].contractAddress();
                releaseTimes[i] = _simpleVestingContracts[i].releaseTime();
            }
            else {
                beneficiaryWallets[i] = _scheduledVestingContracts[(i - _simpleVestingContracts.length)].contractAddress();
                releaseTimes[i] = _scheduledVestingContracts[(i - _simpleVestingContracts.length)].releaseTime();
            }
        }

        return (beneficiaryWallets, releaseTimes); 
    }


    // Vests the specified beneficiary wallet address for the given time, Function can only be called by "owner". Returns the address the contract is deployed to. 
    function vestTokens(address sender, address beneficiary, uint256 amount, uint256 releaseTime) public onlyOwner() returns (address) {

        // Creates an instance of a TokenLock contract.
        TokenLock newVestedLock = new TokenLock(_gaussToken, sender, beneficiary, amount, releaseTime);

        // Transfers the tokens to the TokenLock contract, locking the tokens until the releaseTime is met.
        // Also adds the deployed contract to an array of all deployed Simple Token Lock contracts.
        _gaussToken.transfer(newVestedLock.contractAddress(), amount);
        _simpleVestingContracts.push(newVestedLock);

        emit VestingCreated(beneficiary, newVestedLock.contractAddress(), amount);
        return newVestedLock.contractAddress();
    }


    // Vests the specified beneficiary wallet address for the given time, Function can only be called by "owner". Returns the address the contract is deployed to. 
    function scheduledVesting(address sender, address beneficiary, uint256 amount, uint256[] memory amountsList, uint256[] memory lockTimes) public onlyOwner() returns (address) {

        require(amountsList.length == lockTimes.length, "scheduledVesting(): amountsList and lockTimes do not containt the same number of items");

        // Creates an instance of a ScheduledTokenLock contract.
        ScheduledTokenLock newScheduledLock = new ScheduledTokenLock (
            _gaussToken,
            sender,
            beneficiary,
            amount,
            amountsList,
            lockTimes
        );

        // Transfers the tokens to the ScheduledTokenLock contract, locking the tokens over the specified schedule.
        // Also adds the address of the deployed contract to an array of all deployed Scheduled Token Lock contracts.
        _gaussToken.transfer(newScheduledLock.contractAddress(), amount);
        _scheduledVestingContracts.push(newScheduledLock);

        emit VestingCreated(beneficiary, newScheduledLock.contractAddress(), amount);
        return newScheduledLock.contractAddress();
    }


    /*  Vests the wallet holding the Community Pool funds over a specific time period.
            - Total Community Pool Tokens are 112,500,000, 45% of total supply.
            - As the wallet is unlocked, the tokens will be distributed into the community supply pool.

            Release Schedule is as follows:
                Launch, Month 0:    25,000,000 tokens released
                Months 1 - 6:       1,250,000 tokens released per month
                Months 7 - 23:      4,444,444 tokens released per month
                Month 24:           4,444,452 tokens released                                         */
    function _lockCommunityTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x4249B05E707FeeA3FB034071C66e5A227C230C2f;
        uint256 initialAmount = 97500000 * _decimalsAmount;     // Note: Less than total Pool size because 15 million tokens are immediately sent to the Crowdsale and thus do not get routed through the Vault.
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseAmounts[i] = 10000000 * _decimalsAmount;
            }
            else if (i >= 1 && i <= 6){
                releaseAmounts[i] = 1250000 * _decimalsAmount;
            }
            else if (i >= 7 && i <= 23) {
                releaseAmounts[i] = 4444444 * _decimalsAmount;
            }
            else {
                releaseAmounts[i] = 4444452 * _decimalsAmount;
            }
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Liquidity Pool funds over a specific time period.
            - Total Liquidity Pool Tokens are 20,000,000, 8% of total supply.

            Release Schedule is as follows:
                Month 4:    10,000,000 tokens released
                Month 8:    10,000,000 tokens released                              */
    function _lockLiquidityTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x17cA40C901Af4C31Ed9F5d961b16deD9a4715505;
        uint256 initialAmount = 20000000 * _decimalsAmount;
        uint256 indexNum = 2;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        releaseAmounts[0] = 10000000 * _decimalsAmount;
        releaseAmounts[1] = 10000000 * _decimalsAmount;

        // Initializes the time periods that tokens will be released over.
        releaseTimes[0] = (120 days);
        releaseTimes[1] = (240 days);

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Charitable Fund over a specific time period.
            - Total Charitable Fund Tokens are 15,000,000, 6% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        1,111,111 tokens released (Used to create redistribution expirement)
                Month 6 - 22:           771,605 tokens released per Month
                Month 23:               771,604 tokens released                                            */
    function _lockCharitableFundTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x7d74E237825Eba9f4B026555f17ecacb2b0d78fE;
        uint256 initialAmount = 15000000 * _decimalsAmount;
        uint256 indexNum = 19;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseAmounts[i] = 1111111 * _decimalsAmount;
            }
            else if (i >= 1 && i <= 17){
                releaseAmounts[i] = 771605 * _decimalsAmount;
            }
            else {
                releaseAmounts[i] = 771604 * _decimalsAmount;
            }
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = (150 days + ((30 days) * i));
            }
        } 

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Advisor Pool over a specific time period.
            - Total Advisor Pool Tokens are 6,500,000, 2.6% of total supply.

            Release Schedule is as follows:
                Months 0 - 24:          260,000 tokens released per Month   */
    function _lockAdvisorTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x3e3049A80590baF63B6aC8D74F5CbB31584059bB;
        uint256 initialAmount = 6500000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 260000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Core Team Pool over a specific time period.
            - Total Core Team Pool Tokens are 25,000,000, 10% of total supply.

            Release Schedule is as follows:
                Month 5:        6,250,000 tokens released
                Month 10:       6,250,000 tokens released
                Month 15:       6,250,000 tokens released
                Month 20:       6,250,000 tokens released                      */
    function _lockCoreTeamTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x747dDE9cb0b8B86ef1d221077055EE9ec4E70b89;
        uint256 initialAmount = 25000000 * _decimalsAmount;
        uint256 indexNum = 4;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 6250000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            releaseTimes[i] = ((150 days) + (i * 150 days));
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Marketing Funds over a specific time period.
            - Total Marketing Funds Tokens are 15,000,000, 6% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        600,000 tokens released
                Month 1 - 24:           600,000 tokens released per Month       */
    function _lockMarketingTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x46ceE8F5F3e30aF7b62374249907FB97563262f5;
        uint256 initialAmount = 15000000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 600000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Operations and Developement Funds over a specific time period.
            - Total Operations and Developement tokens are 15,000,000, 6% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        600,000 tokens released
                Month 1 - 24:           600,000 tokens released per Month                        */
    function _lockOpsDevTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0xF9f41Bd5C7B6CF9a3C6E13846035005331ed940e;
        uint256 initialAmount = 15000000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 600000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Vesting Incentive Funds over a specific time period.
            - Total Vesting Incentive Tokens are 12,500,000, 5% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        500,000 tokens released
                Month 1 - 24:           500,000 tokens released per Month               */
    function _lockVestingIncentiveTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0xe3778Db10A5E8b2Bd1B68038F2cEFA835aa46b45;
        uint256 initialAmount = 12500000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 500000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);   
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Reserve Pool over a specific time period.
            - Total Reserve Pool Tokens are 28,500,000, 11.4% of total supply.

            Release Schedule is as follows:
                Months 0, 4, 8, 12, 16, 20:      4,750,000 tokens released per month   */
    function _lockReserveTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0xf02fD116EEfB47E394721356B36D3350972Cc0c7;
        uint256 initialAmount = 28500000 * _decimalsAmount;
        uint256 indexNum = 6;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 4750000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            releaseTimes[i] = ((120 days) * i);
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    // Function to allow "owner" to upgarde the contract using a UUPS Proxy.
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}