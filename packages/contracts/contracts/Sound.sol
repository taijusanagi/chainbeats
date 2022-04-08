//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "hardhat/console.sol";

contract Sound is ERC721 {
    mapping(uint256 => bytes32) seeds;

    function toLiteralString(bytes memory input)
        internal
        pure
        returns (string memory)
    {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory output = new bytes(2 + input.length * 2);
        for (uint256 i = 0; i < input.length; i++) {
            output[0 + i * 2] = alphabet[uint256(uint8(input[i] >> 4))];
            output[1 + i * 2] = alphabet[uint256(uint8(input[i] & 0x0f))];
        }
        return string(output);
    }

    // sample rate 割り切れる数にしてもいいかも
    // 最低の値と最大の値を入れたい
    function random(uint256 tokenId) internal view returns (uint256) {
        uint256 randomnumber = uint256(
            keccak256(abi.encodePacked(seeds[tokenId], tokenId))
        ) % 990;
        return randomnumber + 10;
    }

    function reverseUint32(uint32 input) internal pure returns (uint32 v) {
        v = input;
        v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);
        v = (v >> 16) | (v << 16);
    }

    function reverseUint16(uint16 input) internal pure returns (uint16 v) {
        v = input;
        v = (v >> 8) | (v << 8);
    }

    // function reverseUint8(uint8 input) internal pure returns (uint8 v) {
    //     v = input;
    //     v = (v >> 4) | (v << 4);
    // }

    using Counters for Counters.Counter;
    using Strings for uint256;
    using Base64 for bytes;

    Counters.Counter private _tokenIdTracker;

    string public imageUrlBase;
    string public animationUrlBase;

    bytes4 constant chunkID = "RIFF";
    // dev: this setting makes difference from original js implementation, so need further investigation
    uint32 constant chunkSize = 4 + (8 + subchunk1Size) + (8 + subchunk2Size);
    bytes4 constant format = "WAVE";

    bytes4 constant subchunk1ID = "fmt ";
    uint32 constant subchunk1Size = 16;
    uint16 constant audioFormat = 1;
    uint16 constant numChannels = 1;
    uint32 constant sampleRate = 3000;
    uint32 constant byteRate = (sampleRate * numChannels * bitsPerSample) / 8;
    uint16 constant blockAlign = (numChannels * bitsPerSample) / 8;
    uint16 constant bitsPerSample = 16;

    bytes4 constant subchunk2ID = "data";
    uint32 constant subchunk2Size =
        (sampleRate * numChannels * bitsPerSample) / 8;

    int16 constant crest = 16383;
    int16 constant trough = -16383;

    constructor() ERC721("Sound", "SOUND") {}

    function riffChunk() public pure returns (bytes memory) {
        return abi.encodePacked(chunkID, chunkSize, format);
    }

    function fmtChunk() public pure returns (bytes memory) {
        return
            abi.encodePacked(
                subchunk1ID,
                reverseUint32(subchunk1Size),
                reverseUint16(audioFormat),
                reverseUint16(numChannels),
                reverseUint32(sampleRate),
                reverseUint32(byteRate),
                reverseUint16(blockAlign),
                reverseUint16(bitsPerSample)
            );
    }

    function dataChunkPrefix() public pure returns (bytes memory) {
        return abi.encodePacked(subchunk2ID, reverseUint32(subchunk2Size));
    }

    function getWavePrefix() public pure returns (bytes memory) {
        return abi.encodePacked(riffChunk(), fmtChunk(), dataChunkPrefix());
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Sound: URI query for nonexistent token");
        bytes memory metadata = getMetadata(tokenId);
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    metadata.encode()
                )
            );
    }

    function mint(address to) external payable virtual {
        uint256 tokenId = _tokenIdTracker.current();
        seeds[tokenId] = blockhash(block.number - 1);
        _mint(to, tokenId);
        _tokenIdTracker.increment();
    }

    function getMetadata(uint256 tokenId) public view returns (bytes memory) {
        bytes memory data;

        bytes memory up;
        bytes memory down;

        bytes memory crestBytes = abi.encodePacked(
            reverseUint16(uint16(crest))
        );
        bytes memory troughBytes = abi.encodePacked(
            reverseUint16(uint16(trough))
        );

        uint256 ramdom = random(tokenId);
        // uint256 ramdom = 30;
        // uint256 pulse = 50;

        for (uint256 i = 0; i < (ramdom * 9000) / 10000; i++) {
            up = abi.encodePacked(up, crestBytes);
        }

        for (uint256 i = 0; i < (ramdom * 1000) / 10000; i++) {
            down = abi.encodePacked(down, troughBytes);
        }

        {
            bool isUp = false;
            for (uint256 i = 0; i < sampleRate / ramdom; i++) {
                data = abi.encodePacked(data, isUp ? up : down);
                isUp = !isUp;
            }
        }

        bytes memory sound = abi.encodePacked(
            "data:audio/wav;base64,",
            abi.encodePacked(getWavePrefix(), data).encode()
        );

        console.logBytes(getWavePrefix());
        // bytes memory text = abi.encodePacked(
        //     "data:text/plain;base64,",
        //     abi.encodePacked(getWavePrefix(), data).encode()
        // );

        return
            abi.encodePacked(
                '{"name": "Sound #',
                tokenId.toString(),
                '", "description": "A unique piece of sound represented entirely on-chain.',
                '", "image": "',
                '<svg width=\\"350\\" height=\\"350\\" viewBox=\\"0 0 350 350\\" xmlns=\\"http://www.w3.org/2000/svg\\"><foreignObject x=\\"0\\" y=\\"0\\" width=\\"350\\" height=\\"350\\"><html xmlns=\\"http://www.w3.org/1999/xhtml\\"><style>@font-face{font-family: \\"Nintendoid1\\"; font-style: normal; font-weight: 400; src: url(data:font/ttf;base64,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) format(\\"woff2\\");}html{background: black; padding: 1px; font-family: Nintendoid1; font-size: 6px; color: white; animation-duration: 0.01s; animation-name: textflicker; animation-iteration-count: infinite; animation-direction: alternate;}h1{font-size: 5em;}@keyframes textflicker{from{text-shadow: 1px 0 0 #ea36af, -2px 0 0 #75fa69;}to{text-shadow: 2px 0.5px 2px #ea36af, -1px -0.5px 2px #75fa69;}}</style><div style=\\"width: 350px; height: 350px; color: white; word-break: break-all;\\"><h1> CHAIN BEAT </h1><p>',
                toLiteralString(data),
                "</p></div></html></foreignObject></svg>",
                '", "animation_url": "',
                sound,
                '"}'
            );
    }
}
