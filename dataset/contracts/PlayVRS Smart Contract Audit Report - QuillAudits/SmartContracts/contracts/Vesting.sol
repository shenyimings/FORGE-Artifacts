//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * This contract handles the vesting of our governance token. It is similar to OpenZeppelin's VestingWallet contract, but handles the vesting of specific ERC20 tokens to multiple beneficiaries.
 * A beneficiary can be added through `addBeneficiary` method, the corresponding amount of token will be transferred from the caller to this contract, which will be released to the beneficiary following a given vesting schedule.
 * No matter when the tokens are transferred to this contract via the `addBeneficiary` method, they will follow the vesting schedule as if they were locked from the beginning.
 * Consequently, if the vesting has already started, new tokens sent to this contract for the newly added beneficiary may partly be immediately releasable.
 * There is a multi-sig manager address, who can change beneficiary addresses in emergency cases (e.g. the beneficiary lost his private key).
 */
contract Vesting {
    using SafeERC20 for IERC20;

    uint256 public constant PROPORTION_DENOMINATOR = 10_000;

    // multi-sig manager address
    address public manager;

    // the target ERC20 token for vesting
    address public tokenAddress;

    // mapping (beneficiaryAddress => total amount vesting to the beneficiary)
    mapping(address => uint256) public beneficiaryAmount;
    // mapping (beneficiaryAddress => # of released token)
    mapping(address => uint256) public released;
    // total released token amount
    uint256 totalReleased;

    /**
     * Vesting schedule parameters
     *
     * startSecond: vesting start time (in Unix timestamp)
     * stageSecond: Each vesting stage (in second after `startSecond`)
     * unlockProportion: Unlocked proportion of tokens, between[0, `PROPORTION_DENOMINATOR`]
     *
     * The lengths of `stageSecond` and `unlockProportion` are the same and unlockProportion[0] should always be 0.
     * For example, in the case of stageSecond = [0, 1000, 2000] and unlockProportion = [0, 3000, 7000],
     * - timestamp < `startSecond + 0`, 0% of tokens are unlocked
     * - `startSecond + 0` <= timestamp < `startSecond + 1000`, 30% tokens are unlocked
     * - `startSecond + 1000` <= timestamp < `startSecond + 2000`, 70% tokens are unlocked
     * - `startSecond + 2000` <= timestamp, 100% tokens are unlocked
     */
    uint256 public startSecond;
    uint256[] public stageSecond;
    uint256[] public unlockProportion;

    // Token released to the corresponding beneficiary
    event ReleaseToken(address indexed beneficiary, uint256 amount);

    // Manager changed from currentManager to newManager.
    event TransferManagement(address indexed currentManager, address indexed newManager);

    // Beneficiary changed from originalBeneficiary to newBeneficiary.
    event ChangeBeneficiary(address indexed originalBeneficiary, address indexed newBeneficiary, address indexed executor);
 
    // A new beneficiary with specified vesting amount added by the executor.
    event AddBeneficiary(address indexed beneficiary, address indexed executor, uint256 amount);

    constructor(
        address _manager,
        address _tokenAddress,
        uint256 _start,
        uint256[] memory _stages,
        uint256[] memory _unlockProportion
    ) {
        require(address(_manager) != address(0), "Vesting: zero address is not allowed");   
        require(address(_tokenAddress) != address(0), "Vesting: zero address is not allowed");  

        require(_stages.length == _unlockProportion.length, "Vesting: _stages and _unlockProportion should have the same length");
        require(_stages[0] == 0 && _unlockProportion[0] == 0, "Vesting: first stage and unlockProportion should be 0");
        for (uint256 i = 1; i < _stages.length; i++) {
            require(_stages[i] > _stages[i - 1], "Vesting: invalid _stages");
            require(_unlockProportion[i] > _unlockProportion[i - 1], "Vesting: invalid _unlockProportion");
        }
        
        manager = _manager;
        tokenAddress = _tokenAddress;

        startSecond = _start;
        for (uint256 i = 0; i < _stages.length; i++) {
            stageSecond.push(_stages[i]);
            unlockProportion.push(_unlockProportion[i]);
        }
    }

    function transferManagement(address _newManager) external {
        require(msg.sender == manager, "Unauthorized");
        require(address(_newManager) != address(0), "Vesting: zero addresses not allowed");  

        emit TransferManagement(manager, _newManager);

        manager = _newManager;
    }

    /**
     * Add a new beneficiary with the given vesting amount.
     * The given amount of token will be transferred from `msg.sender` to this contract.
     * The caller should have approved this contract to spend his token before calling this function.
     *
     * NOTE:
     * No matter when, the token for vesting will follow the vesting schedule as if they were locked from the beginning.
     * Consequently, if the vesting has already started, new tokens sent to this contract for the newly added beneficiary may partly be immediately releasable.
     */
    function addBeneficiary(address _beneficiary, uint256 _amount) external {
        require(beneficiaryAmount[_beneficiary] == 0, "Beneficiary already exists");
        beneficiaryAmount[_beneficiary] = _amount;

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        emit AddBeneficiary(_beneficiary, msg.sender, _amount);
    }

    /**
     * Beneficiary calls this function to request releasing vested tokens which have been unlocked according to the vesting schedule.
     */
    function release() external {
        require(
            beneficiaryAmount[msg.sender] != 0,
            "Only beneficiaries receive."
        );

        uint256 scheduledRelease = vestingAmountSchedule(
            msg.sender,
            block.timestamp
        );

        require(
            scheduledRelease > released[msg.sender],
            "Tokens not available."
        );

        uint256 releasable = scheduledRelease - released[msg.sender];

        released[msg.sender] += releasable;
        totalReleased += releasable;
        
        emit ReleaseToken(msg.sender, releasable);

        // send ERC20 token to `msg.sender`.
        IERC20(tokenAddress).safeTransfer(
            msg.sender,
            releasable
        );
    }

    /**
     * The scheduled vest amount of a certain beneficiary.
     */
    function vestingAmountSchedule(address beneficiary, uint256 timestamp)
        public
        view
        returns (uint256 amount)
    {
        return
            (vestingProportionSchedule(timestamp) *
             beneficiaryAmount[beneficiary]) / PROPORTION_DENOMINATOR;
    }

    /**
     * Returns scheduled vesting proportion.
     * Returns between [0, PROPORTION_DENOMINATOR] since floating numbers are not supported.
     */
    function vestingProportionSchedule(uint256 timestamp)
        public
        view
        returns (uint256 nominator)
    {
        for (uint i = 0; i < stageSecond.length; i++) {
            if (timestamp < startSecond + stageSecond[i]) {
                return unlockProportion[i];
            }
        }
        return PROPORTION_DENOMINATOR;
    }

    /**
     * Change beneficiary address
     * Only beneficiaries or manager are supposed to call.
     */
    function changeBeneficiary(
        address _originalBeneficiary, 
        address _newBeneficiary
    ) 
        external 
    {
        require(beneficiaryAmount[_originalBeneficiary] != 0, "Not a beneficiary");
        require(beneficiaryAmount[_newBeneficiary] == 0, "The new beneficiary already exists");

        require(msg.sender == _originalBeneficiary || msg.sender == manager, "Unauthorized request");

        emit ChangeBeneficiary(_originalBeneficiary, _newBeneficiary, msg.sender);

        beneficiaryAmount[_newBeneficiary] = beneficiaryAmount[_originalBeneficiary];
        beneficiaryAmount[_originalBeneficiary] = 0;
        
        released[_newBeneficiary] = released[_originalBeneficiary];
        released[_originalBeneficiary] = 0;
    }
}
