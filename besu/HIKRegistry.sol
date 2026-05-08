// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title HIKRegistry v4.0
 * @dev Auditor-grade provenance registry for HumanisKind AI governance.
 *
 * Key changes from v3.0:
 *   - Authorized signers: only approved addresses can anchor batches
 *   - BatchAnchored event includes policy metadata (version, violation count, receipt count)
 *   - An auditor can verify policy applicability on-chain without downloading IPFS manifests
 *   - Last anchored sequence tracking for chain gap detection
 */
contract HIKRegistry {

    // ── Access Control ───────────────────────────────────────────────────────

    address public owner;
    mapping(address => bool) public authorizedSigners;
    uint256 public lastAnchoredSeq;

    modifier onlyOwner() {
        require(msg.sender == owner, "HIKRegistry: caller is not the owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedSigners[msg.sender], "HIKRegistry: caller is not an authorized signer");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedSigners[msg.sender] = true;
    }

    function grantSigner(address signer) external onlyOwner {
        authorizedSigners[signer] = true;
        emit SignerGranted(signer);
    }

    function revokeSigner(address signer) external onlyOwner {
        authorizedSigners[signer] = false;
        emit SignerRevoked(signer);
    }

    // ── Events ───────────────────────────────────────────────────────────────

    event BatchAnchored(
        bytes32 indexed merkleRoot,
        address indexed signer,
        string  ipfsUri,
        uint32  policyVersion,
        uint16  violationCount,
        uint32  receiptCount,
        uint256 timestamp
    );

    event SignerGranted(address indexed signer);
    event SignerRevoked(address indexed signer);

    // ── Storage ──────────────────────────────────────────────────────────────

    struct BatchRecord {
        address signer;
        uint256 timestamp;
        string  ipfsUri;
        uint32  policyVersion;
        uint16  violationCount;
        uint32  receiptCount;
    }

    mapping(bytes32 => BatchRecord) private _batches;
    mapping(bytes32 => bool) private _anchored;

    error BatchAlreadyAnchored(bytes32 merkleRoot);

    // ── Core ─────────────────────────────────────────────────────────────────

    /**
     * @dev Anchors a Merkle root with policy metadata. Only authorized signers.
     *
     * @param merkleRoot    Merkle root of the batch (SHA-256 of all receipts)
     * @param ipfsUri       IPFS URI of the full batch manifest
     * @param policyVersion KMIR ruleset semver encoded: major*10000 + minor*100 + patch
     *                      e.g. v4.0.0 = 40000, v3.1.0 = 30100
     * @param violationCount Number of KMIR/SLM violations in this batch
     * @param receiptCount  Number of receipts in the Merkle tree
     * @param batchSeq      Sequence number of the last receipt in this batch
     */
    function anchorBatch(
        bytes32 merkleRoot,
        string  memory ipfsUri,
        uint32  policyVersion,
        uint16  violationCount,
        uint32  receiptCount,
        uint256 batchSeq
    ) external onlyAuthorized {
        if (_anchored[merkleRoot]) {
            revert BatchAlreadyAnchored(merkleRoot);
        }

        _batches[merkleRoot] = BatchRecord({
            signer:         msg.sender,
            timestamp:      block.timestamp,
            ipfsUri:        ipfsUri,
            policyVersion:  policyVersion,
            violationCount: violationCount,
            receiptCount:   receiptCount
        });
        _anchored[merkleRoot] = true;

        if (batchSeq > lastAnchoredSeq) {
            lastAnchoredSeq = batchSeq;
        }

        emit BatchAnchored(
            merkleRoot,
            msg.sender,
            ipfsUri,
            policyVersion,
            violationCount,
            receiptCount,
            block.timestamp
        );
    }

    /**
     * @dev Retrieves the record for an anchored Merkle root.
     */
    function getBatch(bytes32 merkleRoot) external view returns (
        address signer,
        uint256 timestamp,
        string memory ipfsUri,
        uint32 policyVersion,
        uint16 violationCount,
        uint32 receiptCount
    ) {
        require(_anchored[merkleRoot], "HIKRegistry: batch not anchored");
        BatchRecord memory record = _batches[merkleRoot];
        return (
            record.signer,
            record.timestamp,
            record.ipfsUri,
            record.policyVersion,
            record.violationCount,
            record.receiptCount
        );
    }

    /**
     * @dev Returns the last anchored batch sequence for chain gap detection.
     */
    function getLastAnchoredSeq() external view returns (uint256) {
        return lastAnchoredSeq;
    }

    /**
     * @dev Checks if a Merkle root has been anchored.
     */
    function isAnchored(bytes32 merkleRoot) external view returns (bool) {
        return _anchored[merkleRoot];
    }

    // ── Legacy compatibility ─────────────────────────────────────────────────

    /**
     * @dev Legacy registerAsset for backward compatibility.
     *      Wraps anchorBatch with default policy metadata.
     *      Will be removed in v5.0.
     */
    function registerAsset(bytes32 manifestHash, string memory ipfsUri) external onlyAuthorized {
        if (_anchored[manifestHash]) {
            revert BatchAlreadyAnchored(manifestHash);
        }
        _batches[manifestHash] = BatchRecord({
            signer:         msg.sender,
            timestamp:      block.timestamp,
            ipfsUri:        ipfsUri,
            policyVersion:  40000,
            violationCount: 0,
            receiptCount:   1
        });
        _anchored[manifestHash] = true;

        emit BatchAnchored(
            manifestHash,
            msg.sender,
            ipfsUri,
            40000,
            0,
            1,
            block.timestamp
        );
    }
}
