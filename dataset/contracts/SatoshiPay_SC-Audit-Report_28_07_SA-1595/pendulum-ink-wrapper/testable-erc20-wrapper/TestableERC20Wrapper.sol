// This file does not define a pragma version because it is meant to be compiled with Solang and Solang ignores
// pragma definitions, see [here](https://solang.readthedocs.io/en/latest/language/pragmas.html).

import "polkadot";

contract TestableERC20Wrapper {
    string private immutable _name;
    string private immutable _symbol;
    uint8 private immutable _decimals;

    bytes1 private immutable _variant;
    bytes1 private immutable _index;

    // This can be either 4 or 12 bytes long
    bytes12 private immutable _code;
    bytes32 private immutable _issuer;

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Emitted when `value` tokens are minted to one account
     *
     */
    event Mint(address indexed to, uint256 value);

    /**
     * @dev Emitted when `value` tokens are burned from one account
     *
     */
    event Burn(address indexed from, uint256 value);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        bytes1 variant_,
        bytes1 index_,
        bytes12 code_,
        bytes32 issuer_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        _variant = variant_;
        _index = index_;

        _code = code_;
        _issuer = issuer_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public returns (uint256) {
        bytes currency = createCurrencyId();
        bytes input = currency;

        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1101,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        uint128 totalSupplyU128 = abi.decode(raw_data, (uint128));
        uint256 totalSupplyU256 = uint256(totalSupplyU128);
        return totalSupplyU256;
    }

    function balanceOf(address _owner) public returns (uint256) {
        // Encode currency and address
        bytes currency = createCurrencyId();
        bytes owner = abi.encode(_owner);
        // Concatenate the already encoded values with abi.encodePacked()
        bytes input = abi.encodePacked(currency, owner);

        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1102,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        uint128 balanceU128 = abi.decode(raw_data, (uint128));
        uint256 balanceU256 = uint256(balanceU128);
        return balanceU256;
    }

    function transfer(address _to, uint256 _amount) public returns (bool) {
        address from = msg.sender;
        if (from == address(0)) {
            revert("ERC20InvalidSender");
        }
        if (_to == address(0)) {
            revert("ERC20InvalidReceiver");
        }

        bytes currency = createCurrencyId();
        bytes to = abi.encode(_to);

        uint128 amountU128 = convertU256toU128(_amount);
        bytes amount = abi.encode(amountU128);

        bytes input = abi.encodePacked(currency, to, amount);
        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1103,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        // If the call to chain_extension was successful, the raw_data will contain only `0`s
        bool success = isBytesAllZeros(raw_data);

        emit Transfer(msg.sender, _to, _amount);
        return success;
    }

    function allowance(
        address _owner,
        address _spender
    ) public returns (uint256) {
        bytes currency = createCurrencyId();
        bytes owner = abi.encode(_owner);
        bytes spender = abi.encode(_spender);
        bytes input = abi.encodePacked(currency, owner, spender);

        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1104,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        uint128 allowanceU128 = abi.decode(raw_data, (uint128));
        uint256 allowanceU256 = uint256(allowanceU128);
        return allowanceU256;
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        address owner = msg.sender;
        if (owner == address(0)) {
            revert("ERC20InvalidApprover");
        }
        if (_spender == address(0)) {
            revert("ERC20InvalidSpender");
        }

        bytes currency = createCurrencyId();
        bytes spender = abi.encode(_spender);

        //In ERC20, amount u256::MAX means unlimited approval, but chain uses u128::MAX. So we convert accordingly if that is the case.
        bytes amount;
        if (_amount == 2 ** 256 - 1) {
            amount = abi.encode(2 ** 128 - 1);
        } else {
            uint128 amountU128 = convertU256toU128(_amount);
            amount = abi.encode(amountU128);
        }

        bytes input = abi.encodePacked(currency, spender, amount);
        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1105,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        // If the call to chain_extension was successful, the raw_data will contain only `0`s
        bool success = isBytesAllZeros(raw_data);

        emit Approval(msg.sender, _spender, _amount);
        return success;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public returns (bool) {
        bytes from = abi.encode(_from);
        bytes currency = createCurrencyId();
        bytes to = abi.encode(_to);

        uint128 amountU128 = convertU256toU128(_amount);
        bytes amount = abi.encode(amountU128);

        bytes input = abi.encodePacked(from, currency, to, amount);
        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1106,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        // If the call to chain_extension was successful, the raw_data will contain only `0`s
        bool success = isBytesAllZeros(raw_data);

        emit Transfer(_from, _to, _amount);
        return success;
    }

    function mint(address _to, uint256 _amount) public returns (bool) {
        bytes currency = createCurrencyId();
        bytes to = abi.encode(_to);

        uint128 amountU128 = convertU256toU128(_amount);
        bytes amount = abi.encode(amountU128);

        bytes input = abi.encodePacked(currency, to, amount);
        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1107,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        // If the call to chain_extension was successful, the raw_data will contain only `0`s
        bool success = isBytesAllZeros(raw_data);

        emit Mint(_to, _amount);
        return success;
    }

    function burn(address _from, uint256 _amount) public returns (bool) {
        bytes currency = createCurrencyId();
        bytes from = abi.encode(_from);

        uint128 amountU128 = convertU256toU128(_amount);
        bytes amount = abi.encode(amountU128);

        bytes input = abi.encodePacked(currency, from, amount);
        (uint32 result_chain_ext, bytes raw_data) = chain_extension(
            (1 << 16) + 1108,
            input
        );
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        // If the call to chain_extension was successful, the raw_data will contain only `0`s
        bool success = isBytesAllZeros(raw_data);

        emit Burn(_from, _amount);
        return success;
    }

    function createCurrencyId() private view returns (bytes) {
        bytes memory currency = new bytes(0);
        // We use the knowledge we have about our `CurrencyId` enum to craft the encoding
        if (_variant == 0) {
            // Native
            currency = abi.encode(_variant);
        } else if (_variant == 1) {
            // XCM(_index)
            currency = abi.encode(_variant, _index);
        } else if (_variant == 2) {
            // Stellar { StellarNative, AlphaNum4, AlphaNum12 }
            if (_index == 0) {
                // StellarNative
                currency = abi.encode(_variant, _index);
            } else if (_index == 1) {
                // AlphaNum4 { code: Bytes4, issuer: AssetIssuer }
                // We make sure that the code is 4 bytes long
                bytes4 code = bytes4(_code);
                currency = abi.encode(_variant, _index, code, _issuer);
            } else if (_index == 2) {
                // AlphaNum12 { code: Bytes12, issuer: AssetIssuer }
                currency = abi.encode(_variant, _index, _code, _issuer);
            } else {
                require(false, "Invalid Stellar variant");
            }
        } else {
            require(false, "Invalid currency variant");
        }
        return currency;
    }

    function isBytesAllZeros(bytes memory data) private pure returns (bool) {
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] != 0) {
                return false;
            }
        }
        return true;
    }

    // If we don't use this function to convert from uint256 to uint128,
    // then the chain extensions will just silently use u128.max() as the value instead of erroring
    function convertU256toU128(uint256 value) private pure returns (uint128) {
        require(
            value <= type(uint128).max,
            "Value exceeds maximum representable uint128"
        );

        uint128 result = uint128(value);
        return result;
    }
}
