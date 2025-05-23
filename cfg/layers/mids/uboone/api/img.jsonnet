// Produce config for WC 3D imaging subgraph

local low = import "../../../low.jsonnet";
local pg = low.pg;
local wc = low.wc;

function(services, params) function(anode) 
    local ident = low.util.idents(anode);
    local img = low.img(anode);

    local wfm = {
        type: 'WaveformMap',
        name: ident,
        data: {
            filename: params.img.charge_error_file,
        },
    };

    local slicing(min_tbin=0, max_tbin=0, ext="", span=4,
                  active_planes=[0,1,2], masked_planes=[], dummy_planes=[]) =
        pg.pnode({
            type: "MaskSlices",
            name: ident+ext,
            data: {
                wiener_tag: "wiener"+ident,
                charge_tag: "gauss"+ident,
                error_tag: "gauss_error"+ident,
                tick_span: span,
                anode: wc.tn(anode),
                min_tbin: min_tbin,
                max_tbin: max_tbin,
                active_planes: active_planes,
                masked_planes: masked_planes,
                dummy_planes: dummy_planes,
            },
        }, nin=1, nout=1, uses=[anode]);


    // Inject signal uncertainty.
    local sigunc = 
        pg.pnode({
            type: 'ChargeErrorFrameEstimator',
            name: ident,
            data: {
                intag: "gauss"+ident,
                outtag: 'gauss_error'+ident,
                anode: wc.tn(anode),
	        rebin: 4,  // this number should be consistent with the waveform_map choice
	        fudge_factors: [2.31, 2.31, 1.1],  // fudge factors for each plane [0,1,2]
	        time_limits: [12, 800],  // the unit of this is in ticks
                errors: wc.tn(wfm),
            },
        }, nin=1, nout=1, uses=[wfm, anode]);


    low.pg.pipeline([
        sigunc,
        slicing(span=params.img.span),
        img.tiling(),
        img.clustering(),
        img.grouping(),
        img.charge_solving(),   // fixme: a few optins we may want to allow to specify in variant params
    ], ident)

