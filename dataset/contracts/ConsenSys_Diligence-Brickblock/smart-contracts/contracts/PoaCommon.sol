pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./PoaProxyCommon.sol";
import "./external/SafeMathPower.sol";


/**
  @title Firstly, PoaCommon acts as a convention between:
  - PoaToken
  - PoaCrowdsale
  to use agreed upon storage for getting & setting
  variables which are used by both contracts.

  Secondly, it has a set of shared functions.

  Thirdly, it inherits from PoaProxyCommon to adhere to the agreed
  upon storage slots for getting & setting PoaProxy related storage.
*/
contract PoaCommon is PoaProxyCommon {
  using SafeMath for uint256;
  using SafeMathPower for uint256;

  // The fee paid to the BBK network per crowdsale investment and per payout
  // NOTE: Tracked in permille (and NOT percent) to reduce dust and
  // inaccuracies caused by integer division
  uint256 public constant feeRateInPermille = 5; // read: 0.5%

  // An enum representing all stages a contract can be in.
  // Different stages enable or restrict certain functionality.
  enum Stages {
    Preview,           // 0
    PreFunding,        // 1
    FiatFunding,       // 2
    EthFunding,        // 3
    FundingSuccessful, // 4
    FundingCancelled,  // 5
    TimedOut,          // 6
    Active,            // 7
    Terminated         // 8
  }

  /***********************
  * Start Common Storage *
  ***********************/

  // Represents current stage
  Stages public stage;

  // Issuer in charge of starting sale, paying fee and handling payouts
  address public issuer;

  // Custodian in charge of taking care of asset and payouts
  address public custodian;

  // IPFS hash storing the proof of custody provided by custodian
  bytes32[2] internal proofOfCustody32_;

  // ERC20 totalSupply
  uint256 internal totalSupply_;

  // Tracks the total amount of tokens sold during the FiatFunding stage
  uint256 public fundedFiatAmountInTokens;

  // Tracks the Fiat investments per user raised during the FiatFunding stage
  mapping(address => uint256) public fundedFiatAmountPerUserInTokens;

  // Tracks the total amount of ETH raised during the EthFunding stage.
  // NOTE: We can't use `address(this).balance` because after activating the
  // POA contract, its balance will become `claimable` by the issuer and can
  // therefore no longer be used to calculate balances.
  uint256 public fundedEthAmountInWei;

  // Tracks the ETH investments per user raised during the EthFunding stage
  mapping(address => uint256) public fundedEthAmountPerUserInWei;

  // Tracks unclaimed payouts per user
  mapping(address => uint256) public unclaimedPayoutTotals;

  // ERC20 paused - Used for enabling/disabling token transfers
  bool public paused;

  // Indicates if poaToken has been initialized
  bool public tokenInitialized;

  // Indicated if the initial fee paid after the crowdsale
  bool public isActivationFeePaid;

  /*********************
  * End Common Storage *
  *********************/

  /**************************
  * Start Crowdsale Storage *
  **************************/

  /*
    Crowdsale storage must be declared in PoaCommon in order to
    avoid storage overwrites by PoaCrowdsale.
  */

  // Bool indicating whether or not crowdsale proxy has been initialized
  bool public crowdsaleInitialized;

  // Used for checking when contract should move from PreFunding to FiatFunding or EthFunding stage
  uint256 public startTimeForFundingPeriod;

  // Maximum duration of fiat funding period in seconds
  uint256 public durationForFiatFundingPeriod;

  // Maximum duration of ETH funding period in seconds
  uint256 public durationForEthFundingPeriod;

  // Maximum duration of activation period in seconds
  uint256 public durationForActivationPeriod;

  // bytes32 representation fiat currency symbol used to get rate
  bytes32 public fiatCurrency32;

  // Amount needed before moving to 'FundingSuccessful', calculated in fiat
  uint256 public fundingGoalInCents;

  // Used for keeping track of actual funded amount in fiat during FiatFunding stage
  uint256 public fundedFiatAmountInCents;

  /************************
  * End Crowdsale Storage *
  ************************/

  /*************************
  * Start Common Modifiers *
  *************************/

  modifier onlyCustodian() {
    require(msg.sender == custodian);
    _;
  }

  modifier onlyIssuer() {
    require(msg.sender == issuer);
    _;
  }

  modifier atStage(Stages _stage) {
    require(stage == _stage);
    _;
  }

  modifier atEitherStage(Stages _stage, Stages _orStage) {
    require(stage == _stage || stage == _orStage);
    _;
  }

  modifier atMaxStage(Stages _stage) {
    require(stage <= _stage);
    _;
  }

  /**
    @notice Check that the most common hashing algo is used (keccak256)
    and that its length is correct. In theory, it could be different.
    But the use of this functionality is limited to "onlyCustodian"
    so this validation should suffice.
  */
  modifier validIpfsHash(bytes32[2] _ipfsHash) {
    bytes memory _ipfsHashBytes = bytes(to64LengthString(_ipfsHash));
    require(_ipfsHashBytes.length == 46);
    require(_ipfsHashBytes[0] == 0x51);
    require(_ipfsHashBytes[1] == 0x6D);
    require(keccak256(abi.encodePacked(_ipfsHashBytes)) != keccak256(abi.encodePacked(proofOfCustody())));
    _;
  }

  /***********************
  * End Common Modifiers *
  ***********************/


  /************************
  * Start Regular Getters *
  ************************/

  /**
    @notice Converts proofOfCustody from bytes32 to string
    @return string
   */
  function proofOfCustody()
    public
    view
    returns (string)
  {
    return to64LengthString(proofOfCustody32_);
  }

  /**********************
  * End Regular Getters *
  **********************/


  /***********************************
  * Start Common Lifecycle Functions *
  ***********************************/

  function enterStage(
    Stages _stage
  )
    internal
  {
    stage = _stage;
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature("logStage(uint256)", uint256(_stage))
    );
  }

  /*********************************
  * End Common Lifecycle Functions *
  *********************************/


  /*********************************
  * Start Common Utility Functions *
  *********************************/

  /// @notice Utility function calculating the necessary fee for a given amount
  /// @return uint256 Payable fee
  function calculateFee(
    uint256 _value
  )
    public
    pure
    returns (uint256)
  {
    return feeRateInPermille.mul(_value).div(1000);
  }

  /// @notice Pay fee to FeeManager contract
  /// @return true if fee payment succeeded, or false if it failed
  function payFee(
    uint256 _value
  )
    internal
    returns (bool)
  {
    require(
      // NOTE: It's an `internal` call and we know exactly what
      // we're calling so it's safe to ignore this solium warning.
      // solium-disable-next-line security/no-call-value
      getContractAddress("FeeManager")
        .call.value(_value)(abi.encodeWithSignature("payFee()"))
    );
  }

  /// @notice Checks if a given address has invested during the EthFunding stage.
  function isEthInvestor(
    address _buyer
  )
    internal
    view
    returns (bool)
  {
    return fundedEthAmountPerUserInWei[_buyer] > 0;
  }

  /// @notice Checks if a given address has invested during the FiatFunding stage.
  function isFiatInvestor(
    address _buyer
  )
    internal
    view
    returns (bool)
  {
    return fundedFiatAmountPerUserInTokens[_buyer] > 0;
  }

  /// @notice Checks if a given address is whitelisted
  /// @return true if address is whitelisted, false if not
  function isWhitelisted(
    address _address
  )
    public
    view
    returns (bool _isWhitelisted)
  {
    bytes4 _signature = bytes4(keccak256("whitelisted(address)"));
    address _whitelistContract = getContractAddress("Whitelist");

    assembly {
      let _pointer := mload(0x40)  // Set _pointer to free memory pointer
      mstore(_pointer, _signature) // Store _signature at _pointer
      mstore(add(_pointer, 0x04), _address) // Store _address at _pointer. Offset by 4 bytes for previously stored _signature

      // staticcall(g, a, in, insize, out, outsize) => returns 0 on error, 1 on success
      let result := staticcall(
        gas,                // g = gas: whatever was passed already
        _whitelistContract, // a = address: _whitelist address assigned from getContractAddress()
        _pointer,           // in = mem in  mem[in..(in+insize): set to _pointer pointer
        0x24,               // insize = mem insize  mem[in..(in+insize): size of signature (bytes4) + bytes32 = 0x24
        _pointer,           // out = mem out  mem[out..(out+outsize): output assigned to this storage address
        0x20                // outsize = mem outsize  mem[out..(out+outsize): output should be 32byte slot (bool size = 0x01 < slot size 0x20)
      )

      // Revert if not successful
      if iszero(result) {
        revert(0, 0)
      }

      _isWhitelisted := mload(_pointer) // Assign result to returned value
      mstore(0x40, add(_pointer, 0x24)) // Advance free memory pointer by largest _pointer size
    }
  }

  /// @notice Takes a single bytes32 and returns a max 32 char long string
  /// @param _data single bytes32 representation of a string
  function to32LengthString(
    bytes32 _data
  )
    internal
    pure
    returns (string)
  {
    // create a new empty bytes array with same max length as input
    bytes memory _bytesString = new bytes(32);

    // an assembly block is necessary to directly change memory layout
    assembly {
      mstore(add(_bytesString, 0x20), _data)
    }

    // measure string by searching for first occurrance of empty byte
    for (uint256 _bytesCounter = 0; _bytesCounter < 32; _bytesCounter++) {
      if (_bytesString[_bytesCounter] == 0x00) {
        break;
      }
    }

    // directly set the length of bytes array through assembly
    assembly {
      mstore(_bytesString, _bytesCounter)
    }

    // cast bytes array to string
    return string(_bytesString);
  }

  /// @notice Needed for longer strings up to 64 chars long
  /// @param _data 2 length sized array of bytes32
  function to64LengthString(
    bytes32[2] _data
  )
    internal
    pure
    returns (string)
  {
    // create a new empty bytes array with same max length as input
    bytes memory _bytesString = new bytes(64);

    // store both of the 32 byte items packed, leave space for length at first 32 bytes
    assembly {
      mstore(add(_bytesString, 0x20), mload(_data))
      mstore(add(_bytesString, 0x40), mload(add(_data, 0x20)))
    }

    // measure string by searching for first occurrance of empty byte
    for (uint256 _bytesCounter = 0; _bytesCounter < 64; _bytesCounter++) {
      if (_bytesString[_bytesCounter] == 0x00) {
        break;
      }
    }

    // directly set the length of bytes array through assembly
    assembly {
      mstore(_bytesString, _bytesCounter)
    }

    // cast bytes array to string
    return string (_bytesString);
  }

  /*******************************
  * End Common Utility Functions *
  *******************************/
}
