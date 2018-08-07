
// <ACEStransformID>InvODT.Academy.P3D65_DisplayP3_80nits.a1.1</ACEStransformID>
// <ACESuserName>ACES 1.0 Inverse Output - DisplayP3 80 nits</ACESuserName>

// 
// Inverse Output Device Transform - P3D65 with the sRGB gamma
//



import "ACESlib.Utilities";
import "ACESlib.Transform_Common";
import "ACESlib.ODT_Common";
import "ACESlib.Tonescales";



/* --- ODT Parameters --- */
const Chromaticities DISPLAY_PRI = P3D65_PRI;
const float DISPLAY_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ( DISPLAY_PRI, 1.0);

// NOTE: The EOTF is *NOT* gamma 2.4, it follows IEC 61966-2-1:1999
const float DISPGAMMA = 2.4;
const float OFFSET = 0.055;

const float EIZO_WHITE = 80.0;
const float EIZO_BLACK = 0.05;


void main 
(
    input varying float rIn, 
    input varying float gIn, 
    input varying float bIn, 
    input varying float aIn,
    output varying float rOut,
    output varying float gOut,
    output varying float bOut,
    output varying float aOut
)
{

    float outputCV[3] = { rIn, gIn, bIn};

    // Decode to linear code values with inverse transfer function
    float linearCV[3];
    // moncurve_f with gamma of 2.4 and offset of 0.055 matches the EOTF found in IEC 61966-2-1:1999 (sRGB)
    linearCV[0] = moncurve_f( outputCV[0], DISPGAMMA, OFFSET);
    linearCV[1] = moncurve_f( outputCV[1], DISPGAMMA, OFFSET);
    linearCV[2] = moncurve_f( outputCV[2], DISPGAMMA, OFFSET);

    // Convert from display primary encoding
    // Display primaries to CIE XYZ
    float XYZ[3] = mult_f3_f44( linearCV, DISPLAY_PRI_2_XYZ_MAT);

    // Apply CAT from assumed observer adapted white to ACES white point
    XYZ = mult_f3_f33( XYZ, invert_f33( D60_2_D65_CAT));

    // CIE XYZ to rendering space RGB
    linearCV = mult_f3_f44( XYZ, XYZ_2_AP1_MAT);

    // Scale linear code value to luminance
    float rgbPre[3];
    rgbPre[0] = linCV_2_Y( linearCV[0], EIZO_WHITE, EIZO_BLACK);
    rgbPre[1] = linCV_2_Y( linearCV[1], EIZO_WHITE, EIZO_BLACK);
    rgbPre[2] = linCV_2_Y( linearCV[2], EIZO_WHITE, EIZO_BLACK);

    // Apply the tonescale independently in rendering-space RGB
    float rgbPost[3];
    rgbPost[0] = segmented_spline_c9_rev( rgbPre[0]);
    rgbPost[1] = segmented_spline_c9_rev( rgbPre[1]);
    rgbPost[2] = segmented_spline_c9_rev( rgbPre[2]);

    // Rendering space RGB to OCES
    float oces[3] = mult_f3_f44( rgbPost, AP1_2_AP0_MAT);

    rOut = oces[0];
    gOut = oces[1];
    bOut = oces[2];
    aOut = aIn;
}
