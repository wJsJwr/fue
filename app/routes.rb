module Routes
    Prefix = '/fue'
    Table = {
        'index'   => '/',
        'login'   => '/login',
        'logout'  => '/logout',
        'new'     => '/new',
        'search'  => '/search',
        'detail'  => '/detail/:expr_id',
        'history' => '/detail/:expr_id/',
        'hisentry'=> '/detail/:expr_id/:ver',
        'comment' => '/comment/:expr_id/:ver',
        'card'    => '/card',
        'update'  => '/update/:expr_id'
    }
    def Routes.const_missing(name)
        if Table[name.to_s.downcase].nil?
            raise "Route entry not found: #{name} => #{name.to_s.downcase}"
        else
            "#{Prefix}#{Table[name.to_s.downcase]}"
        end
    end

    def Routes.url_for(ha)
        if ha['entry'] == 'detail'
            url = "#{Prefix}/detail"
            unless ha['expr_id'].nil?
                url << "/#{ha['expr_id']}"
                unless ha['version'].nil?
                    if ha['version'] == 0
                        url << '/'
                    else
                        url << "/#{ha['version']}"
                    end
                end
            end
            url
        elsif ha['entry'] == 'update'
            url = "#{Prefix}/update"
            unless ha['expr_id'].nil?
                url << "/#{ha['expr_id']}"
            end
            url
        elsif ha['entry'] == 'comment'
            url = "#{Prefix}/comment"
            unless ha['expr_id'].nil?
                url << "/#{ha['expr_id']}"
                unless ha['version'].nil?
                    url << "/#{ha['version']}"
                end
            end
            url
        else
            "#{Prefix}/"
        end

    end

end