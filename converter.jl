using SeticoreCapnp, Blio, DataFrames, ArgParse
using RadioInterferometry, Dates
using Statistics
using Plots

function cli()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--stamps", "-s"
        help = "Stamp file"
    end
    return parse_args(s)
end

function requantise(stamp)
    stddev = std(abs.(reinterpret(real(eltype(stamp.data)), stamp.data)))
    arr = clamp.(round.(reinterpret(real(eltype(stamp.data)), stamp.data)/stddev.*13), Int8(typemin(Int8)), Int8(typemax(Int8)))
    converted = convert(Array{Complex{Int8}}, arr)
    # APCT (stamps) to PTCA (raw)
    permuted = permutedims(converted, (2, 4, 3, 1))
    return permuted
end

function rawheader(stamp)

    s = NamedTuple(stamp)
    mjd = datetime2julian(unix2datetime(stamp.tstart)) - 2_400_000.5
    smjd = 24*60*60*(mjd%1)

    headerdict = Dict{Symbol, Any}(
        :blocsize => sizeof(stamp.data),
        :npol => s.numPolarizations,
        :obsnchan => s.numChannels*s.numAntennas,
        :nbits => 8, # required for RAW format
        :obsfreq => s.fch1 + (s.numChannels - 1)*s.foff/2,
        :obsbw => s.foff*s.numChannels, # in MHz
        :tbin => s.tsamp,
        :directio => 0,
        :pktidx => 0,
        :beam_id => s.beam,
        :nbeam => 1,
        :nants => s.numAntennas,
        :ra_str => deg2hmsstr(s.ra, hourwidth=2),
        :dec_str => deg2dmsstr(s.dec),
        :stt_imjd => floor(Int, mjd),
        :stt_smjd => floor(Int, smjd),
        :src_name => s.sourceName,
        :telescop => s.telescopeId)

    h = GuppiRaw.Header(headerdict)

    return h
end

function main()
    args = cli()
    reader = CapnpReader(Stamp, args["stamps"])
    for (i, stamp) in enumerate(reader)
        h = rawheader(stamp)
        d = requantise(stamp)
        open("test_$i.raw", "w") do io
            write(io, h)
            write(io, d)
        end
    end
end

(abspath(PROGRAM_FILE) == @__FILE__) && main()