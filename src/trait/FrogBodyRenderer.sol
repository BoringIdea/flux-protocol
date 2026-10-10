// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice On-chain 48x48 frog backgrounds, body palettes and skin patterns.
contract FrogBodyRenderer {
    string internal constant OUTLINE = "#101610";

    function renderBackground(uint16 background, uint16 style)
        external
        pure
        returns (string memory)
    {
        (string memory base, string memory light, string memory dark) = backgroundColors(background);
        return string.concat(
            '<rect width="48" height="48" fill="',
            base,
            '"/>',
            _scene(style % 14, light, dark),
            '<g id="shadow" fill="',
            dark,
            '" opacity=".52"><rect x="7" y="41" width="34" height="2"/>',
            '<rect x="11" y="43" width="26" height="1"/></g>'
        );
    }

    function renderBody(uint16 bodyStyle, uint16 skinStyle) external pure returns (string memory) {
        (string memory color, string memory light, string memory shade, string memory belly) =
            bodyColors(bodyStyle);
        return string.concat(
            _body(color, light, shade, belly), _skin(skinStyle % 6, light, shade, accent(bodyStyle))
        );
    }

    function backgroundColors(uint16 value)
        public
        pure
        returns (string memory base, string memory light, string memory dark)
    {
        uint256 i = value % 12;
        string[12] memory bases = [
            "#78978A",
            "#777FEA",
            "#E89386",
            "#168F90",
            "#C9C39F",
            "#A69AC4",
            "#F3A46F",
            "#66BCE8",
            "#594F8F",
            "#66846B",
            "#E889B6",
            "#A8D9DF"
        ];
        string[12] memory lights = [
            "#9DB7AC",
            "#A9AEFF",
            "#FFC0B4",
            "#55C4C2",
            "#EDE7C5",
            "#D2C7E8",
            "#FFD49D",
            "#C7ECFF",
            "#B39DDB",
            "#A2B98E",
            "#FFC4DF",
            "#E5FAFC"
        ];
        string[12] memory darks = [
            "#526E62",
            "#5058B7",
            "#B9645C",
            "#087071",
            "#918B68",
            "#786D91",
            "#B96855",
            "#397EA8",
            "#332B61",
            "#3B5940",
            "#A9517D",
            "#639CA5"
        ];
        return (bases[i], lights[i], darks[i]);
    }

    function bodyColors(uint16 value)
        public
        pure
        returns (string memory color, string memory light, string memory shade, string memory belly)
    {
        uint256 i = value % 12;
        string[12] memory colors = [
            "#91DB22",
            "#32D583",
            "#21C7D9",
            "#F2C94C",
            "#A77BFF",
            "#FF7A59",
            "#E8F2E8",
            "#34414F",
            "#F08DB7",
            "#4169D8",
            "#B6F000",
            "#89563D"
        ];
        string[12] memory lights = [
            "#C9FF59",
            "#8CFFC1",
            "#8DF3FF",
            "#FFF29B",
            "#D8C2FF",
            "#FFB29E",
            "#FFFFFF",
            "#748292",
            "#FFD0E2",
            "#87A8FF",
            "#E6FF70",
            "#D89A6F"
        ];
        string[12] memory shades = [
            "#5EAD18",
            "#188C59",
            "#137E92",
            "#B98923",
            "#6848B8",
            "#BC4937",
            "#AABDB3",
            "#18212A",
            "#B65380",
            "#254293",
            "#668F00",
            "#4F2E22"
        ];
        string[12] memory bellies = [
            "#F4E7B3",
            "#F4E7B3",
            "#F4E7B3",
            "#E8F2E2",
            "#F4E7B3",
            "#F4E7B3",
            "#F7D9B5",
            "#D8CBA8",
            "#FFF0D2",
            "#F2DDA9",
            "#F3E4B3",
            "#F2D4A8"
        ];
        return (colors[i], lights[i], shades[i], bellies[i]);
    }

    function accent(uint16 value) public pure returns (string memory) {
        string[12] memory colors = [
            "#FF4FC3",
            "#8B5CF6",
            "#FF5B45",
            "#5B4BE1",
            "#FFE552",
            "#55E6D3",
            "#E94B64",
            "#FFB84D",
            "#4ED6C5",
            "#FFB13B",
            "#9A55E8",
            "#46CFE0"
        ];
        return colors[value % 12];
    }

    function _scene(uint256 style, string memory light, string memory dark)
        internal
        pure
        returns (string memory)
    {
        if (style == 1) {
            return string.concat(
                '<g id="pond-ripples" fill="',
                light,
                '" opacity=".72"><rect x="4" y="36" width="8" height="1"/><rect x="1" y="40" width="14" height="1"/><rect x="36" y="38" width="10" height="1"/><rect x="32" y="43" width="15" height="1"/></g>'
            );
        }
        if (style == 2) {
            return string.concat(
                '<g id="pixel-clouds" fill="',
                light,
                '" opacity=".8"><rect x="2" y="6" width="12" height="3"/><rect x="5" y="4" width="6" height="3"/><rect x="34" y="9" width="12" height="3"/><rect x="37" y="7" width="6" height="3"/></g>'
            );
        }
        if (style == 3) {
            return
            '<g id="fireflies" fill="#FFF6A6"><rect x="5" y="8" width="2" height="2"/><rect x="40" y="6" width="1" height="1"/><rect x="43" y="18" width="2" height="2"/><rect x="4" y="25" width="1" height="1"/></g>';
        }
        if (style == 4) {
            return string.concat(
                '<g id="reeds" fill="',
                dark,
                '"><rect x="3" y="23" width="2" height="15"/><rect x="6" y="27" width="2" height="12"/><rect x="43" y="21" width="2" height="17"/><rect x="40" y="29" width="2" height="10"/></g>'
            );
        }
        if (style == 5) {
            return string.concat(
                '<g id="bubbles" fill="none" stroke="',
                light,
                '" stroke-width="1" opacity=".48"><rect x="4" y="7" width="4" height="4"/><rect x="39" y="5" width="3" height="3"/><rect x="41" y="24" width="5" height="5"/><rect x="2" y="29" width="3" height="3"/></g>'
            );
        }
        if (style == 6) {
            return string.concat(
                '<g id="sunny-day" fill="#FFE552"><rect x="37" y="4" width="7" height="7"/><rect x="39" y="2" width="3" height="11"/><rect x="35" y="6" width="11" height="3"/></g><g fill="',
                light,
                '" opacity=".7"><rect x="2" y="8" width="10" height="2"/><rect x="5" y="6" width="5" height="2"/></g>'
            );
        }
        if (style == 7) {
            return
            '<g id="star-field" fill="#FFF3A4"><rect x="4" y="5" width="2" height="5"/><rect x="2" y="7" width="6" height="1"/><rect x="40" y="8" width="2" height="5"/><rect x="38" y="10" width="6" height="1"/><rect x="7" y="17" width="1" height="1"/><rect x="42" y="20" width="1" height="1"/></g>';
        }
        if (style == 8) {
            return string.concat(
                '<g id="crescent-moon"><rect x="36" y="4" width="8" height="10" fill="#FFF0AD"/><rect x="39" y="3" width="6" height="9" fill="',
                dark,
                '"/></g>'
            );
        }
        if (style == 9) {
            return
            '<g id="grassland"><rect x="0" y="35" width="48" height="13" fill="#397A43"/><rect x="1" y="38" width="46" height="10" fill="#70B85A"/><rect x="4" y="31" width="2" height="8" fill="#397A43"/><rect x="42" y="31" width="2" height="8" fill="#397A43"/></g>';
        }
        if (style == 10) {
            return
            '<g id="forest"><g fill="#355C3D"><rect x="1" y="13" width="8" height="26"/><rect x="39" y="11" width="8" height="28"/></g><g fill="#754D32"><rect x="4" y="23" width="3" height="18"/><rect x="41" y="21" width="3" height="20"/></g><g fill="#4E8A4F"><rect x="0" y="8" width="12" height="17"/><rect x="36" y="6" width="12" height="17"/></g></g>';
        }
        if (style == 11) {
            return
            '<g id="lotus-pond"><rect x="0" y="35" width="48" height="13" fill="#4F9A82"/><g fill="#75C7AE"><rect x="2" y="38" width="14" height="2"/><rect x="33" y="41" width="13" height="2"/></g><g fill="#FF82B7"><rect x="4" y="30" width="5" height="5"/><rect x="2" y="32" width="9" height="2"/><rect x="40" y="32" width="4" height="5"/><rect x="38" y="34" width="8" height="2"/></g></g>';
        }
        if (style == 12) {
            return
            '<g id="rainbow" opacity=".8"><rect x="2" y="4" width="17" height="2" fill="#FF6B6B"/><rect x="2" y="6" width="15" height="2" fill="#FFB84D"/><rect x="2" y="8" width="13" height="2" fill="#FFE552"/><rect x="2" y="10" width="11" height="2" fill="#6EDB78"/><rect x="2" y="12" width="9" height="2" fill="#65B9FF"/><rect x="2" y="14" width="7" height="2" fill="#9B74E8"/></g>';
        }
        if (style == 13) {
            return string.concat(
                '<g id="rain-shower"><g fill="',
                dark,
                '" opacity=".62"><rect x="4" y="5" width="1" height="4"/><rect x="9" y="10" width="1" height="5"/><rect x="40" y="6" width="1" height="5"/><rect x="44" y="13" width="1" height="4"/><rect x="3" y="20" width="1" height="4"/><rect x="42" y="25" width="1" height="5"/></g></g>'
            );
        }
        return "";
    }

    function _body(string memory c, string memory l, string memory s, string memory k)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            '<g id="frog-outline" fill="',
            OUTLINE,
            '"><rect x="12" y="12" width="10" height="10"/><rect x="26" y="12" width="10" height="10"/><rect x="10" y="17" width="28" height="17"/><rect x="9" y="23" width="30" height="13"/><rect x="5" y="29" width="14" height="11"/><rect x="29" y="29" width="14" height="11"/><rect x="4" y="37" width="17" height="4"/><rect x="27" y="37" width="17" height="4"/></g>',
            '<g id="frog-body" fill="',
            c,
            '"><rect x="13" y="13" width="8" height="9"/><rect x="27" y="13" width="8" height="9"/><rect x="11" y="18" width="26" height="15"/><rect x="10" y="24" width="28" height="11"/><rect x="6" y="30" width="12" height="9"/><rect x="30" y="30" width="12" height="9"/><rect x="5" y="38" width="15" height="2"/><rect x="28" y="38" width="15" height="2"/></g>',
            '<g id="body-shade" fill="',
            s,
            '"><rect x="36" y="24" width="2" height="9"/><rect x="39" y="32" width="3" height="6"/><rect x="31" y="35" width="8" height="3"/><rect x="7" y="35" width="8" height="3"/></g>',
            '<g id="belly" fill="',
            k,
            '"><rect x="19" y="29" width="10" height="5"/><rect x="17" y="31" width="14" height="2"/><rect x="21" y="28" width="6" height="1"/></g>',
            '<g id="body-highlight" fill="',
            l,
            '"><rect x="11" y="21" width="2" height="6"/><rect x="7" y="31" width="2" height="4"/><rect x="14" y="25" width="1" height="2"/></g>',
            '<g id="limb-lines" fill="',
            OUTLINE,
            '"><rect x="11" y="32" width="2" height="4"/><rect x="12" y="35" width="4" height="1"/><rect x="35" y="32" width="2" height="4"/><rect x="32" y="35" width="4" height="1"/></g>'
        );
    }

    function _skin(uint256 style, string memory light, string memory shade, string memory a)
        internal
        pure
        returns (string memory)
    {
        if (style == 1) {
            return
            '<g id="freckles" fill="#101610"><rect x="14" y="20" width="1" height="1"/><rect x="18" y="22" width="2" height="1"/><rect x="28" y="20" width="1" height="1"/><rect x="32" y="22" width="2" height="1"/></g>';
        }
        if (style == 2) {
            return string.concat(
                '<g id="poison-spots" fill="',
                a,
                '"><rect x="12" y="20" width="3" height="2"/><rect x="33" y="21" width="3" height="3"/><rect x="15" y="29" width="4" height="3"/><rect x="28" y="28" width="3" height="2"/></g>'
            );
        }
        if (style == 3) {
            return string.concat(
                '<g id="moss-patches" fill="#315F45"><rect x="11" y="19" width="5" height="2"/><rect x="31" y="26" width="5" height="2"/><rect x="17" y="33" width="3" height="2"/></g><g fill="',
                light,
                '"><rect x="13" y="20" width="1" height="1"/></g>'
            );
        }
        if (style == 4) {
            return string.concat(
                '<g id="tiger-stripes" fill="',
                OUTLINE,
                '"><rect x="11" y="20" width="5" height="1"/><rect x="32" y="19" width="5" height="1"/><rect x="10" y="29" width="6" height="1"/><rect x="32" y="30" width="6" height="1"/></g>'
            );
        }
        if (style == 5) {
            return string.concat(
                '<g id="cyber-panels" fill="none" stroke="',
                a,
                '" stroke-width="1"><rect x="12" y="19" width="7" height="5"/><rect x="29" y="19" width="7" height="5"/><rect x="19" y="29" width="10" height="5"/></g>'
            );
        }
        shade;
        return "";
    }
}
