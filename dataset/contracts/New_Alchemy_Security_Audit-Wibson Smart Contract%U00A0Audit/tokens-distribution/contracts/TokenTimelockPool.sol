pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "openzeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


/**
 * @title TokenTimelockPool
 * @author Wibson Development Team <developers@wibson.org>
 * @notice This contract models a pool of tokens to be distributed among beneficiaries,
 * releasing the entire pool on a specific date. There is no need to know the
 * beneficiaries in advance, since the contract allows to add them as time goes by.
 * Tokens that were not distributed by the release date will stay in the pool until
 * they are assigned. In which case, the new beneficiary will be able to release
 * them immediately.
 * @dev Total funds and distributed tokens are controlled to avoid refills done
 * by transferring tokens through the ERC20.
 */
contract TokenTimelockPool is Ownable {
  using SafeERC20 for ERC20Basic;
  using SafeMath for uint256;

  // ERC20 token being held
  ERC20Basic public token;

  // Timestamp (in seconds) when tokens can be released
  uint256 public releaseDate;

  // Maximum amount of tokens to be distributed
  uint256 public totalFunds;

  // Tokens already distributed
  uint256 public distributedTokens;

  // List of beneficiaries added to the pool
  address[] public beneficiaries;

  // Mapping of beneficiary to TokenTimelock contracts addresses
  mapping(address => address[]) public beneficiaryDistributionContracts;

  modifier validAddress(address _addr) {
    require(_addr != address(0));
    require(_addr != address(this));
    _;
  }

  /**
   * @notice Contract constructor.
   * @param _token instance of an ERC20 token.
   * @param _totalFunds Maximum amount of tokens to be distributed among
   *        beneficiaries.
   * @param _releaseDate Timestamp (in seconds) when tokens can be released.
   */
  constructor(
    ERC20Basic _token,
    uint256 _totalFunds,
    uint256 _releaseDate
  ) public validAddress(_token) {
    require(_totalFunds > 0);
    // solium-disable-next-line security/no-block-members
    require(_releaseDate > block.timestamp);

    token = _token;
    totalFunds = _totalFunds;
    distributedTokens = 0;
    releaseDate = _releaseDate;
  }

  /**
   * @notice Adds a beneficiary that will be allowed to extract the tokens after
   *         the release date.
   * @notice Example:
             addBeneficiary(`0x123..`, 100)
             Will create a TokenTimelock instance on which if the `release()` method
             is called after the release date (specified in this contract constructor),
             the amount of tokens (100) will be transferred to the
             beneficiary (`0x123..`).
   * @dev The `msg.sender` must be the owner of the contract.
   * @param _beneficiary Beneficiary that will receive the tokens after the
   * release date.
   * @param _amount of tokens to be released.
   * @return address for the new TokenTimelock contract instance.
   */
  function addBeneficiary(
    address _beneficiary,
    uint256 _amount
  ) public onlyOwner validAddress(_beneficiary) returns (address) {
    require(_beneficiary != owner);
    require(_amount > 0);
    // solium-disable-next-line security/no-block-members
    require(block.timestamp < releaseDate);

    // Check there are sufficient funds and actual token balance.
    require(SafeMath.sub(totalFunds, distributedTokens) >= _amount);
    require(token.balanceOf(address(this)) >= _amount);

    if (!beneficiaryExists(_beneficiary)) {
      beneficiaries.push(_beneficiary);
    }

    // Bookkepping of distributed tokens
    distributedTokens = distributedTokens.add(_amount);

    address tokenTimelock = new TokenTimelock(
      token,
      _beneficiary,
      releaseDate
    );

    // Bookkeeping of distributions contracts per beneficiary
    beneficiaryDistributionContracts[_beneficiary].push(tokenTimelock);

    // Assign the tokens to the beneficiary
    token.safeTransfer(tokenTimelock, _amount);

    return tokenTimelock;
  }

  /**
   * @notice Transfers the remaining tokens that were not locked for any
   *         beneficiary to the owner of this contract.
   * @dev The `msg.sender` must be the owner of the contract.
   * @return true if tokens were reclaimed successfully, reverts otherwise.
   */
  function reclaim() public onlyOwner returns (bool) {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp > releaseDate);
    uint256 reclaimableAmount = token.balanceOf(address(this));

    token.safeTransfer(owner, reclaimableAmount);
    return true;
  }

  /**
   * @notice Gets an array of all the distribution contracts for a given beneficiary.
   * @param _beneficiary address of the beneficiary to whom tokens will be transferred.
   * @return List of TokenTimelock addresses.
   */
  function getDistributionContracts(
    address _beneficiary
  ) public view validAddress(_beneficiary) returns (address[]) {
    return beneficiaryDistributionContracts[_beneficiary];
  }

  /**
   * @notice Checks if a beneficiary was added to the pool at least once.
   * @param _beneficiary address of the beneficiary to whom tokens will be transferred.
   * @return true if beneficiary exists, false otherwise.
   */
  function beneficiaryExists(
    address _beneficiary
  ) internal view returns (bool) {
    return beneficiaryDistributionContracts[_beneficiary].length > 0;
  }
}
