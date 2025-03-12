// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./HexEscapes.sol";
import "./INftMetadata.sol";
import "./StringBuilder.sol";
import "./Utf8.sol";

import "base64-sol/base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev The logic for constructing the NFT metadata for a given Xaya account
 * token on-chain into JSON and a data: URL.
 *
 * There are certain bits of data that can be configured per namespace,
 * and this state is stored in the contract / can be updated by the owner.
 */
contract NftMetadata is INftMetadata, Ownable
{

  /* ************************************************************************ */

  /** @dev Configuration data for a known namespace.  */
  struct NamespaceData
  {

    /** @dev Set to true if there is custom configuration for a namespace.  */
    bool configured;

    /** @dev Description string for names of this namespace.  */
    string description;

    /** @dev Background image used for names in this namespace.  */
    string bgUrl;

    /**
     * @dev Foreground / text colour used in the SVG image for names
     * of this namespace.
     */
    string fgColour;

    /** @dev Value returned for the "type" attribute.  */
    string typ;

  }

  /** @dev Known namespaces for which we return custom metadata.  */
  mapping (string => NamespaceData) public namespaces;

  /** @dev The default configuration for unknown namespaces.  */
  NamespaceData public defaultConfig;

  /** @dev Link to the contract-level metadata.  */
  string public override contractUri;

  /**
   * @dev The base URL used to serve data.  The token ID will be appended
   * to this URI.
   *
   * There were a couple of issues with getting OpenSea to properly handle
   * generated data: URIs.  For this reason, we still implement metadata
   * generation in the contract (so it is fully on-chain), but serve the
   * actual tokenURI from a server that "forwards" the on-chain data.
   *
   * The URI will be queried for metadata and images with "metadata/xns/xname"
   * or "image/xns/xname" appended, where xns and xname are the namespace and
   * name hex-encoded.
   */
  string public dataServerUrl;

  /** @dev Emitted when a namespace is reconfigured.  */
  event NamespaceConfigured (string ns);

  /** @dev Emitted when the contract metadata is updated.  */
  event ContractMetadataUpdated (string url);

  /** @dev Emitted when the data server URL is updated.  */
  event DataServerUpdated (string url);

  /* ************************************************************************ */

  /** @dev Width of the generated SVG.  */
  string internal constant svgWidth = "512";

  /** @dev Height of the generated SVG.  */
  string internal constant svgHeight = "256";

  /**
   * @dev For the SVG generation, we use a table of (maximum) string
   * lengths (in codepoints) and the corresponding font-size to use.
   * These structs are individual entries in that table.
   *
   * When looking through an array of these structs (which is the look-up
   * table), the first entry matching a given string is used.  If none match
   * (as the string is too long), then the last entry is used and the string
   * is truncated to that entry's length with an ellipsis added.
   */
  struct SvgSizeEntry
  {

    /**
     * @dev The maximum length of a string in codepoints to match this
     * table entry.
     */
    uint len;

    /** @dev The font-size to use for a matching string.  */
    string fontSize;

  }

  /* Solidity does not (yet) support simple creation of a constant
     variable holding the look-up table as SvgSizeEntry[].  Thus we
     define the actual table as memory array inside the function below.  */

  /* ************************************************************************ */

  /**
   * @dev The constructor applies the initial configuration of known
   * namespaces.
   */
  constructor ()
  {
    setNamespaceData ("",
        "A generic name for the Xaya platform (of unknown type).",
        "https://arweave.net/TBlWvq3M4jobQLLM7BlI1qdbLqB8_dYC9CLnNJ5CnwE",
        "ffffff", "Unknown");
    setNamespaceData ("p",
        "A player account for the Xaya platform.  All in-game assets are"
        " associated to account NFTs.",
        "https://arweave.net/1-PqW8MR1nM3ZihhsySnlXQAdPjn6rh9zXXcP4TKJRk",
        "ffffff", "Player Account");
    setNamespaceData ("g",
        "The admin account for a game on the Xaya platform.",
        "https://arweave.net/bvDHgYSNAB1yQdlajsmbBDKHFW9SEullON3JKzeiyk4",
        "ffffff", "Game");
    setContractMetadata (
        "https://arweave.net/O3KatG4kpbSTXx5RENrsz83m4x2OYblg2jvqXW_Cu9c");
    setDataServerUrl ("https://nft.xaya.io/polygon/");
  }

  /**
   * @dev Adds or updates the namespace data for a given namespace.  If ns
   * is the empty string, it changes the default configuration instead.
   */
  function setNamespaceData (string memory ns, string memory description,
                             string memory bgUrl, string memory fgColour,
                             string memory typ) public onlyOwner
  {
    NamespaceData storage entry;
    if (bytes (ns).length == 0)
      entry = defaultConfig;
    else
      entry = namespaces[ns];

    entry.configured = true;
    entry.description = description;
    entry.bgUrl = bgUrl;
    entry.fgColour = fgColour;
    entry.typ = typ;

    emit NamespaceConfigured (ns);
  }

  /**
   * @dev Sets the link to the contract-level metadata.
   */
  function setContractMetadata (string memory newUrl) public onlyOwner
  {
    contractUri = newUrl;
    emit ContractMetadataUpdated (newUrl);
  }

  /**
   * @dev Sets the data server base URL to the given value.
   */
  function setDataServerUrl (string memory newUrl) public onlyOwner
  {
    dataServerUrl = newUrl;
    emit DataServerUpdated (newUrl);
  }

  /* ************************************************************************ */

  /**
   * @dev Encodes a given payload of data into a data: URL string.
   */
  function buildDataUrl (string memory mimeType, bytes memory payload)
      internal pure returns (string memory)
  {
    return string (abi.encodePacked (
      "data:", mimeType,
      ";base64,", Base64.encode (payload)
    ));
  }

  /**
   * @dev Encodes a given string as JSON string literal.
   */
  function jsonStringLiteral (string memory str)
      internal pure returns (string memory)
  {
    bytes memory data = bytes (str);

    /* Each codepoint is encoded into a \uXXXX sequence of size 6.  The number
       of codepoints can never be larger than the byte-size of the UTF-8 string
       (even with UTF-16 surrogate pairs).  */
    StringBuilder.Type memory builder = StringBuilder.create (6 * data.length);

    uint offset = 0;
    while (offset < data.length)
      {
        uint32 cp;
        (cp, offset) = Utf8.decodeCodepoint (data, offset);
        StringBuilder.append (builder, HexEscapes.jsonCodepoint (cp));
      }

    return string (abi.encodePacked (
      "\"", StringBuilder.extract (builder), "\""
    ));
  }

  /**
   * @dev Encodes a given string as XML escape sequences.  The string
   * is truncated to the given length.
   */
  function xmlStringLiteral (string memory str, uint maxLen)
      internal pure returns (string memory, uint, bool)
  {
    bytes memory data = bytes (str);

    StringBuilder.Type memory builder = StringBuilder.create (10 * data.length);
    uint len = 0;

    uint offset = 0;
    while (offset < data.length)
      {
        if (len == maxLen)
          return (StringBuilder.extract (builder), len, true);

        uint32 cp;
        (cp, offset) = Utf8.decodeCodepoint (data, offset);
        StringBuilder.append (builder, HexEscapes.xmlCodepoint (cp));
        ++len;
      }

    assert (len <= maxLen);
    return (StringBuilder.extract (builder), len, false);
  }

  /* ************************************************************************ */

  /**
   * @dev Constructs the NFT image as SVG data URL.
   */
  function buildSvgImage (string memory ns, string memory name)
      external override view returns (string memory)
  {
    NamespaceData storage config = namespaces[ns];
    if (!config.configured)
      config = defaultConfig;
    string memory fullName = string (abi.encodePacked (ns, "/", name));

    SvgSizeEntry[3] memory sizeTable = [
      SvgSizeEntry (10, "50"),
      SvgSizeEntry (16, "30"),
      SvgSizeEntry (22, "20")
    ];

    string memory escapedString;
    string memory fontSize;

    {
      uint cpLen;
      bool trunc;
      (escapedString, cpLen, trunc)
          = xmlStringLiteral (fullName, sizeTable[sizeTable.length - 1].len);

      if (trunc)
        {
          escapedString = string (abi.encodePacked (escapedString, "..."));
          fontSize = sizeTable[sizeTable.length - 1].fontSize;
        }
      else
        {
          bool found = false;
          for (uint i = 0; i < sizeTable.length; ++i)
            {
              if (cpLen <= sizeTable[i].len)
                {
                  fontSize = sizeTable[i].fontSize;
                  found = true;
                  break;
                }
            }
          assert (found);
        }
    }

    return buildDataUrl ("image/svg+xml", abi.encodePacked (
      "<?xml version='1.0' ?>"
      "<svg xmlns='http://www.w3.org/2000/svg'"
      " width='", svgWidth, "'"
      " height='", svgHeight, "'>"

      "<image x='0' y='0' width='100%' height='100%'"
      " href='", config.bgUrl, "' />"

      "<text x='50%' y='50%' text-anchor='middle' dominant-baseline='middle'"
      " fill='#", config.fgColour, "'"
      " font-size='", fontSize, "' font-family='sans-serif'>",
      escapedString,
      "</text>"

      "</svg>"
    ));
  }

  /**
   * @dev Constructs the metadata JSON for a given name and returns it
   * as data URI.
   */
  function buildMetadataJson (string memory ns, string memory name)
      external override view returns (string memory)
  {
    NamespaceData storage config = namespaces[ns];
    if (!config.configured)
      config = defaultConfig;
    string memory fullName = string (abi.encodePacked (ns, "/", name));

    string memory attributes = string (abi.encodePacked (
      "[",
        "{",
          "\"trait_type\":\"Namespace\"",
          ",\"value\":", jsonStringLiteral (ns),
        "}",
        ",{",
          "\"trait_type\":\"Name\"",
          ",\"value\":", jsonStringLiteral (name),
        "}",
        ",{",
          "\"trait_type\":\"Type\"",
          ",\"value\":", jsonStringLiteral (config.typ),
        "}",
      "]"
    ));

    string memory imgUri = string (abi.encodePacked (
      dataServerUrl, "image/",
      HexEscapes.hexlify (ns), "/", HexEscapes.hexlify (name)
    ));

    return buildDataUrl ("application/json", abi.encodePacked (
      "{",
        "\"name\":",  jsonStringLiteral (fullName),
        ",\"image\":\"", imgUri, "\""
        ",\"description\":", jsonStringLiteral (config.description),
        ",\"attributes\":", attributes,
      "}"
    ));
  }

  /**
   * @dev Constructs the full metadata URI for a given name, delegating
   * to the configured data server.
   */
  function tokenUriForName (string memory ns, string memory name)
      external override view returns (string memory)
  {
    return string (abi.encodePacked (
      dataServerUrl, "metadata/",
      HexEscapes.hexlify (ns), "/", HexEscapes.hexlify (name)
    ));
  }

  /* ************************************************************************ */

}
